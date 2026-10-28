-- ============================================================================
-- JA3 Tradutor IA - 07_AutoTranslator.lua
-- Orquestrador em Background (CreateRealTimeThread) + Sincronia em Tempo Real
-- da Interface do Mod e do Idioma Destino com o Idioma do Jogo.
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

M.WorkerThread = M.WorkerThread or false
M.IsTranslating = false
M.CancelRequested = false
M.InsideTranslationChanged = false
M.LiveState = M.LiveState or { key = "status_init", args = {} }
M.LiveStatusLine = M.LiveStatusLine or ""
M.LastScanReports = M.LastScanReports or {}
M.HasInitializedOnce = M.HasInitializedOnce or false

function M.SetLiveState(trKey, ...)
	M.LiveState = { key = trKey, args = { ... } }
	M.LiveStatusLine = M.Tr(trKey, ...)
	return M.LiveStatusLine
end

function M.SetLiveRawText(rawStr)
	M.LiveState = nil
	M.LiveStatusLine = tostring(rawStr or "")
	return M.LiveStatusLine
end

function M.GetLiveStatusText()
	if type(M.LiveState) == "table" and M.LiveState.key then
		return M.Tr(M.LiveState.key, table.unpack(M.LiveState.args or {}))
	end
	if type(M.LiveStatusLine) == "string" and M.LiveStatusLine ~= "" then
		return M.LiveStatusLine
	end
	return M.Tr("status_init")
end

function M.IsWorkerRunning()
	local isValid = rawget(_ENV, "IsValidThread")
	if isValid and M.WorkerThread then
		return isValid(M.WorkerThread) and M.IsTranslating
	end
	return M.IsTranslating
end

function M.StopBackgroundTranslation(reasonKeyOrText)
	M.CancelRequested = true
	local delThread = rawget(_ENV, "DeleteThread")
	if M.WorkerThread and delThread then
		pcall(delThread, M.WorkerThread)
	end
	M.WorkerThread = false
	M.IsTranslating = false
	local msg = M.SetLiveState(reasonKeyOrText or "status_paused")
	M.UpdateHudBanner(M.Tr("status_paused"), M.Tr("hud_paused_detail_fmt", msg), 0, 4500)
end

local function build_chunks(uniqueSources, maxItems, maxChars)
	maxItems = math.max(5, math.min(80, tonumber(maxItems) or 35))
	maxChars = math.max(1500, tonumber(maxChars) or 7500)

	local chunks = {}
	local current = {}
	local currentChars = 0

	for i = 1, #uniqueSources do
		local txt = uniqueSources[i]
		local len = #txt + 16
		if #current > 0 and (#current >= maxItems or (currentChars + len) > maxChars) then
			chunks[#chunks + 1] = current
			current = {}
			currentChars = 0
		end
		current[#current + 1] = txt
		currentChars = currentChars + len
	end

	if #current > 0 then
		chunks[#chunks + 1] = current
	end
	return chunks
end

function M.StartBackgroundTranslation(manualTrigger)
	if M.IsWorkerRunning() then
		if not manualTrigger then
			return
		end
		M.StopBackgroundTranslation("status_restarting")
	end

	local createThread = rawget(_ENV, "CreateRealTimeThread")
	local sleepFn = rawget(_ENV, "Sleep")
	if not createThread then return end

	M.CancelRequested = false
	M.IsTranslating = true

	M.WorkerThread = createThread(function()
		local okRun, runErr = pcall(function()
			if sleepFn then sleepFn(150) end

			M.ApplyModUiLocalization()
			local s = M.SyncFromModOptions()
			local targetMeta = M.ResolveLanguage(s.targetLanguage)

			-- 1. Restaura imediatamente todas as traduções já salvas em disco para o idioma destino
			M.LoadLanguageDatabases(targetMeta.code, false)
			local restoredNow = M.ApplySavedTranslationsToMemory(true)
			if restoredNow > 0 then
				M.Log("Restored %d translations in memory for %s.", restoredNow, targetMeta.code)
			end

			-- Se o Mod Editor estiver aberto (ex.: preparando Upload para a Steam Workshop),
			-- não dispara chamadas HTTP automáticas em background para não interferir no empacotamento!
			if not manualTrigger then
				local isModEditorOpened = rawget(_ENV, "IsModEditorOpened")
				local isModEditorMap = rawget(_ENV, "IsModEditorMap")
				if (type(isModEditorOpened) == "function" and isModEditorOpened())
					or (type(isModEditorMap) == "function" and isModEditorMap()) then
					M.SetLiveState("status_paused")
					M.IsTranslating = false
					return
				end
			end

			if not manualTrigger and s.autoTranslate == false then
				M.SetLiveState("status_auto_off_fmt", M.IdMapCount)
				M.IsTranslating = false
				return
			end

			M.SetLiveState("status_scanning")
			if manualTrigger then
				M.UpdateHudBanner(M.Tr("status_scanning"), M.Tr("hud_scanning_detail"), 5, nil)
			end

			local reports = M.ScanAllTargetMods(s)
			M.LastScanReports = reports

			if #reports == 0 then
				M.SetLiveState("status_no_mods")
				if manualTrigger then
					M.UpdateHudBanner(M.Tr("hud_no_mods_title"), M.Tr("hud_no_mods_detail"), 100, 4500)
				end
				M.IsTranslating = false
				return
			end

			-- 2. Passo Zero-API: resolve instantaneamente tudo que já está no cache_<lang>.json
			local cacheHitIdPairs = {}
			local backfilledTextPairs = {}
			local cacheHitsCount = 0
			local totalModEntries = 0
			local totalAlreadyTranslated = 0
			local pendingModTasks = {}

			for _, rep in ipairs(reports) do
				local sameLang = (M.NormalizeLangGroup(rep.sourceLang.code) == M.NormalizeLangGroup(targetMeta.code))
				if sameLang then
					totalModEntries = totalModEntries + rep.totalCount
					totalAlreadyTranslated = totalAlreadyTranslated + rep.totalCount
				else
					local modMissingEntries = {}
					for _, entry in ipairs(rep.entries) do
						totalModEntries = totalModEntries + 1
						local existingById = M.ActiveIdMap[entry.key]
						if type(existingById) == "string" and existingById ~= "" then
							totalAlreadyTranslated = totalAlreadyTranslated + 1
							if not M.ActiveTextCache[entry.sourceText] then
								backfilledTextPairs[entry.sourceText] = existingById
							end
						else
							local existingByText = M.ActiveTextCache[entry.sourceText]
							if type(existingByText) == "string" and existingByText ~= "" then
								cacheHitIdPairs[entry.key] = existingByText
								cacheHitsCount = cacheHitsCount + 1
								totalAlreadyTranslated = totalAlreadyTranslated + 1
							else
								modMissingEntries[#modMissingEntries + 1] = entry
							end
						end
					end

					if #modMissingEntries > 0 then
						pendingModTasks[#pendingModTasks + 1] = {
							report = rep,
							missingEntries = modMissingEntries,
						}
					end
				end
			end

			if cacheHitsCount > 0 or next(backfilledTextPairs) ~= nil then
				M.CommitBatchTranslations(targetMeta.code, cacheHitIdPairs, backfilledTextPairs, true)
				M.Log("Applied %d cached translations instantly!", cacheHitsCount)
			end

			local totalPendingEntries = totalModEntries - totalAlreadyTranslated
			if totalPendingEntries <= 0 or #pendingModTasks == 0 then
				M.SetLiveState("status_done_fmt", totalAlreadyTranslated, targetMeta.display)
				if manualTrigger or cacheHitsCount > 0 then
					M.UpdateHudBanner(
						M.Tr("hud_all_done_title"),
						M.Tr("hud_all_done_detail_fmt", totalAlreadyTranslated, targetMeta.display),
						100,
						5000
					)
				end
				M.IsTranslating = false
				return
			end

			-- 3. Verifica API Key caso haja textos inéditos para traduzir em provedor de nuvem
			local provMeta = M.GetProviderMeta(s.provider)
			if provMeta.requiresKey and M.GetActiveApiKey(s) == "" then
				M.SetLiveState("status_need_key_fmt", totalPendingEntries)
				M.UpdateHudBanner(
					M.Tr("hud_need_key_title"),
					M.Tr("hud_need_key_detail_fmt", totalPendingEntries),
					0,
					12000
				)
				M.IsTranslating = false
				return
			end

			-- 4. Detecta automaticamente se a chave é Gratuita ou Paga e calibra lote/delay anti-429
			M.SetLiveState("status_calibrating")
			M.UpdateHudBanner(
				M.Tr("hud_calibrating_title"),
				M.Tr("hud_calibrating_detail_fmt", totalPendingEntries, targetMeta.display),
				math.floor((totalAlreadyTranslated * 100) / math.max(1, totalModEntries)),
				nil
			)

			local tierRes = M.DetectAndTuneTier(s, false)
			if not tierRes.ok and tierRes.invalidKey then
				M.SetLiveState("status_invalid_key")
				M.UpdateHudBanner(
					M.Tr("hud_invalid_key_title"),
					M.Tr("hud_invalid_key_detail"),
					0,
					12000
				)
				M.IsTranslating = false
				return
			end

			local globalKeysBySource = {}
			for _, task in ipairs(pendingModTasks) do
				for _, entry in ipairs(task.missingEntries) do
					local bucket = globalKeysBySource[entry.sourceText]
					if not bucket then
						bucket = {}
						globalKeysBySource[entry.sourceText] = bucket
					end
					bucket[#bucket + 1] = entry.key
				end
			end

			-- 5. Traduz mod a mod em lotes em background, salvando e aplicando ao vivo a cada lote!
			for _, task in ipairs(pendingModTasks) do
				if M.CancelRequested then break end

				local rep = task.report
				local uniqueForMod = {}
				local seenSrc = {}
				for _, entry in ipairs(task.missingEntries) do
					if not M.ActiveIdMap[entry.key] and not M.ActiveTextCache[entry.sourceText] and not seenSrc[entry.sourceText] then
						seenSrc[entry.sourceText] = true
						uniqueForMod[#uniqueForMod + 1] = entry.sourceText
					end
				end

				if #uniqueForMod > 0 then
					local chunks = build_chunks(uniqueForMod, s.batchSize, s.maxCharsPerBatch)
					for chunkIdx, chunkSources in ipairs(chunks) do
						if M.CancelRequested then break end

						local pct = math.floor((totalAlreadyTranslated * 100) / math.max(1, totalModEntries))
						M.SetLiveState("status_batch_fmt", rep.title, chunkIdx, #chunks, pct)
						M.UpdateHudBanner(
							string.format("%s (%d%%)", rep.title, pct),
							M.Tr("hud_batch_detail_fmt", rep.sourceLang.display, targetMeta.display, chunkIdx, #chunks, totalAlreadyTranslated, totalModEntries),
							pct,
							nil
						)

						local batchRes = M.TranslateUniqueBatch(
							chunkSources,
							rep.sourceLang,
							targetMeta,
							rep.title,
							s,
							function(waitMsg)
								M.SetLiveRawText(waitMsg)
								M.UpdateHudBanner(rep.title, waitMsg, pct, nil)
							end,
							0
						)

						if not batchRes.ok then
							if batchRes.cancelled then
								M.IsTranslating = false
								return
							end
							local pauseReason = M.SetLiveRawText(tostring(batchRes.err or M.Tr("hud_paused_quota_title")))
							M.UpdateHudBanner(M.Tr("hud_paused_quota_title"), pauseReason, pct, 12000)
							M.IsTranslating = false
							return
						end

						local newIdPairs = {}
						local newTextPairs = {}
						for srcText, dstText in pairs(batchRes.translations) do
							newTextPairs[srcText] = dstText
							local matchingKeys = globalKeysBySource[srcText]
							if type(matchingKeys) == "table" then
								for _, k in ipairs(matchingKeys) do
									if not M.ActiveIdMap[k] then
										newIdPairs[k] = dstText
										totalAlreadyTranslated = totalAlreadyTranslated + 1
									end
								end
							end
						end

						M.CommitBatchTranslations(targetMeta.code, newIdPairs, newTextPairs, true)

						local updatedPct = math.floor((totalAlreadyTranslated * 100) / math.max(1, totalModEntries))
						M.UpdateHudBanner(
							string.format("%s (%d%%)", rep.title, updatedPct),
							M.Tr("hud_saved_live_fmt", totalAlreadyTranslated, totalModEntries, targetMeta.display),
							updatedPct,
							nil
						)
					end
				end
			end

			if not M.CancelRequested then
				M.SetLiveState("status_done_fmt", totalAlreadyTranslated, targetMeta.display)
				M.UpdateHudBanner(
					M.Tr("hud_finished_title"),
					M.Tr("hud_finished_detail_fmt", targetMeta.display, totalAlreadyTranslated),
					100,
					6500
				)
			end
		end)

		if not okRun then
			M.Log("Unexpected error in background translator thread: %s", tostring(runErr))
			M.SetLiveRawText("Error: " .. tostring(runErr))
		end

		M.IsTranslating = false
		M.WorkerThread = false
	end)
end

-- Inicialização central idempotente (chamada tanto no boot quanto ao ativar no Mod Manager)
function M.InitializeModLifecycle(triggerSource)
	M.Log("Initializing lifecycle (%s)...", tostring(triggerSource))
	M.ApplyModUiLocalization()
	M.SyncFromModOptions()
	M.RegisterShortcutsAndMenuButtons()
	M.ApplySavedTranslationsToMemory(true)
	M.StartBackgroundTranslation(false)
end

-- ============================================================================
-- Hooks de Mensagens Globais do Motor Haemimont / Jagged Alliance 3
-- ============================================================================

function OnMsg.Autorun()
	M.HasInitializedOnce = true
	M.InitializeModLifecycle("Autorun")
end

function OnMsg.ModsReloaded()
	M.HasInitializedOnce = true
	M.InitializeModLifecycle("ModsReloaded")
end

function OnMsg.ApplyModOptions(mod_id)
	local myId = rawget(_ENV, "CurrentModId") or "JA3TradutorIA"
	if mod_id == myId then
		M.ApplyModUiLocalization()
		local s, langChanged = M.SyncFromModOptions()
		if langChanged then
			local targetMeta = M.ResolveLanguage(s.targetLanguage)
			M.LoadLanguageDatabases(targetMeta.code, true)
			M.ApplySavedTranslationsToMemory(true)
		end
		if s.showHudBanner == false then
			M.DestroyHudBanner()
		end
		if s.autoTranslate ~= false then
			M.StartBackgroundTranslation(false)
		end
	end
end

function OnMsg.ModsUIDialogStarted()
	local createThread = rawget(_ENV, "CreateRealTimeThread")
	local sleepFn = rawget(_ENV, "Sleep")
	if createThread and sleepFn then
		createThread(function()
			for _ = 1, 20 do
				sleepFn(150)
				local modsUi = rawget(_ENV, "g_ModsUIContextObj")
				if type(modsUi) == "table" and modsUi.installed_retrieved then
					M.ApplyModUiLocalization()
					break
				end
			end
		end)
	else
		M.ApplyModUiLocalization()
	end
end

function OnMsg.TranslationChanged()
	if M.InsideTranslationChanged then
		return
	end
	M.InsideTranslationChanged = true
	pcall(function()
		-- 1. Atualiza imediatamente toda a interface do próprio Mod para o novo idioma do jogo!
		M.ApplyModUiLocalization()
		-- 2. Reaplica as traduções de mods salvas (e caso TargetLanguage == "auto", acompanha o novo idioma do jogo!)
		local s = M.LoadSettings()
		local targetMeta = M.ResolveLanguage(s.targetLanguage)
		local prevLoaded = M.LoadedLangCode
		M.LoadLanguageDatabases(targetMeta.code, prevLoaded ~= targetMeta.code)
		M.ApplySavedTranslationsToMemory(true)
		if prevLoaded and prevLoaded ~= targetMeta.code and s.autoTranslate ~= false then
			M.StartBackgroundTranslation(false)
		end
	end)
	M.InsideTranslationChanged = false
end

-- Boot de segurança caso o mod tenha sido carregado após Autorun
do
	local createThread = rawget(_ENV, "CreateRealTimeThread")
	local sleepFn = rawget(_ENV, "Sleep")
	if createThread and sleepFn then
		createThread(function()
			sleepFn(1200)
			if not M.HasInitializedOnce then
				M.HasInitializedOnce = true
				M.InitializeModLifecycle("DelayedBoot")
			else
				M.ApplyModUiLocalization()
				M.RegisterShortcutsAndMenuButtons()
				M.ApplySavedTranslationsToMemory(true)
			end
		end)
	end
end
