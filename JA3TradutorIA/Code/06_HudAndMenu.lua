-- ============================================================================
-- JA3 Tradutor IA - 06_HudAndMenu.lua
-- HUD Discreto em Segundo Plano (Click-Through) + Botão Nativo sincronizado
-- com o idioma atual do jogo + Painel Interativo Completo (Ctrl+Shift+T).
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

M.HudWindow = M.HudWindow or false
M.HudHideThread = M.HudHideThread or false
M.ShortcutTarget = M.ShortcutTarget or false
M.MenuOpen = false

local function mask_api_key(key)
	if type(key) ~= "string" or key == "" then
		return M.Tr("key_not_set")
	end
	if #key <= 8 then
		return M.Tr("key_set_short")
	end
	return M.Tr("key_set_masked_fmt", key:sub(1, 4), key:sub(-4))
end

local function tier_badge_text(settings)
	local t = tostring(settings and settings.detectedTier or "unknown")
	if t == "free" then
		return "<color 120 215 145>" .. M.Tr("badge_free") .. "</color>"
	elseif t == "paid" then
		return "<color 235 195 95>" .. M.Tr("badge_paid") .. "</color>"
	elseif t == "local" then
		return "<color 135 195 245>" .. M.Tr("badge_local") .. "</color>"
	elseif t == "invalid" then
		return "<color 235 95 95>" .. M.Tr("badge_invalid") .. "</color>"
	end
	return "<color 185 185 185>" .. M.Tr("badge_auto") .. "</color>"
end

local function sync_option_to_engine(optKey, optVal)
	local opts = rawget(_ENV, "CurrentModOptions")
	if type(opts) == "table" then
		rawset(opts, optKey, optVal)
	end
end

-- ============================================================================
-- HUD Overlay Não-Intrusivo no Canto Superior Direito
-- ============================================================================

function M.DestroyHudBanner()
	local delThread = rawget(_ENV, "DeleteThread")
	if M.HudHideThread and delThread then
		pcall(delThread, M.HudHideThread)
		M.HudHideThread = false
	end
	if M.HudWindow and M.HudWindow.window_state ~= "destroying" then
		pcall(function() M.HudWindow:Close() end)
	end
	M.HudWindow = false
end

local function ensure_hud_window()
	local term = rawget(_ENV, "terminal")
	local desktop = term and term.desktop
	if not desktop then return nil end

	if M.HudWindow and M.HudWindow.window_state ~= "destroying" and M.HudWindow.parent == desktop then
		return M.HudWindow
	end

	local xWin = rawget(_ENV, "XWindow")
	local xText = rawget(_ENV, "XText")
	local boxFn = rawget(_ENV, "box")
	local rgbaFn = rawget(_ENV, "RGBA")
	if not xWin or not xText or not boxFn or not rgbaFn then
		return nil
	end

	for i = #desktop, 1, -1 do
		local child = desktop[i]
		if child and child.Id == "idJA3TradutorIAHud" and child.window_state ~= "destroying" then
			pcall(function() child:Close() end)
		end
	end

	local win = xWin:new({
		Id = "idJA3TradutorIAHud",
		HAlign = "right",
		VAlign = "top",
		Margins = boxFn(0, 14, 18, 0),
		Padding = boxFn(12, 8, 12, 8),
		BorderWidth = 1,
		BorderColor = rgbaFn(198, 168, 96, 210),
		Background = rgbaFn(18, 22, 20, 225),
		LayoutMethod = "VList",
		LayoutVSpacing = 3,
		MinWidth = 320,
		MaxWidth = 450,
		ZOrder = 1000000,
		HandleMouse = false,
		ChildrenHandleMouse = false,
		FocusOnOpen = "",
	}, desktop)

	xText:new({
		Id = "idHeader",
		Translate = false,
		WordWrap = true,
		HandleMouse = false,
		Padding = boxFn(0, 0, 0, 0),
	}, win)

	xText:new({
		Id = "idDetail",
		Translate = false,
		WordWrap = true,
		HandleMouse = false,
		Padding = boxFn(0, 0, 0, 2),
	}, win)

	local barTrack = xWin:new({
		Id = "idBarTrack",
		HAlign = "stretch",
		MinHeight = 4,
		MaxHeight = 4,
		Background = rgbaFn(55, 62, 58, 220),
		HandleMouse = false,
	}, win)

	xWin:new({
		Id = "idBarFill",
		HAlign = "left",
		MinHeight = 4,
		MaxHeight = 4,
		MinWidth = 0,
		MaxWidth = 420,
		Background = rgbaFn(212, 178, 92, 245),
		HandleMouse = false,
	}, barTrack)

	win:Open()
	M.HudWindow = win
	return win
end

function M.UpdateHudBanner(headerText, detailText, pct0to100, autoHideMs)
	local s = M.LoadSettings()
	if s.showHudBanner == false then
		M.DestroyHudBanner()
		return
	end

	local delThread = rawget(_ENV, "DeleteThread")
	if M.HudHideThread and delThread then
		pcall(delThread, M.HudHideThread)
		M.HudHideThread = false
	end

	local win = ensure_hud_window()
	if not win then return end

	local badge = tier_badge_text(s)
	local headerFormatted = "<color 226 198 125>" .. M.Tr("hud_brand") .. "</color> " .. badge
	if headerText and headerText ~= "" then
		headerFormatted = headerFormatted .. " • <color 235 235 230>" .. tostring(headerText) .. "</color>"
	end
	local detailFormatted = "<color 195 202 196>" .. tostring(detailText or "") .. "</color>"

	for _, child in ipairs(win) do
		if child.Id == "idHeader" then
			child:SetText(headerFormatted)
		elseif child.Id == "idDetail" then
			child:SetText(detailFormatted)
		elseif child.Id == "idBarTrack" then
			local clampPct = math.max(0, math.min(100, tonumber(pct0to100) or 0))
			local fillPx = math.floor((clampPct / 100.0) * 396)
			if child[1] and child[1].Id == "idBarFill" then
				child[1]:SetMinWidth(fillPx)
				child[1]:SetMaxWidth(fillPx)
			end
		end
	end

	win:SetVisible(true)

	if autoHideMs and autoHideMs > 0 then
		local createThread = rawget(_ENV, "CreateRealTimeThread")
		local sleepFn = rawget(_ENV, "Sleep")
		if createThread and sleepFn then
			M.HudHideThread = createThread(function()
				sleepFn(autoHideMs)
				if M.HudWindow and M.HudWindow.window_state ~= "destroying" then
					M.HudWindow:SetVisible(false)
				end
				M.HudHideThread = false
			end)
		end
	end
end

-- ============================================================================
-- Painel de Controle Interativo In-Game (Ctrl+Shift+T / Botão no Idioma do Jogo)
-- ============================================================================

local function show_info_box(title, bodyText)
	local waitMsg = rawget(_ENV, "WaitMessage")
	local untranslated = rawget(_ENV, "Untranslated")
	local term = rawget(_ENV, "terminal")
	if waitMsg and untranslated and term and term.desktop then
		waitMsg(term.desktop, untranslated(title), untranslated(bodyText), untranslated(M.Tr("btn_ok")))
	end
end

local function ask_yes_no(title, bodyText)
	local waitQ = rawget(_ENV, "WaitQuestion")
	local untranslated = rawget(_ENV, "Untranslated")
	local term = rawget(_ENV, "terminal")
	if waitQ and untranslated and term and term.desktop then
		local res = waitQ(
			term.desktop,
			untranslated(title),
			untranslated(bodyText),
			untranslated(M.Tr("btn_yes")),
			untranslated(M.Tr("btn_cancel"))
		)
		return res == "ok"
	end
	return false
end

local function build_mods_report_text()
	local reports = M.LastScanReports
	local s = M.LoadSettings()
	local targetMeta = M.ResolveLanguage(s.targetLanguage)
	M.LoadLanguageDatabases(targetMeta.code, false)

	if type(reports) ~= "table" or #reports == 0 then
		reports = M.ScanAllTargetMods(s)
		M.LastScanReports = reports
	end

	if #reports == 0 then
		return M.Tr("dlg_mods_empty_fmt", M.FormatScopeSetting(s.scanScope))
	end

	local lines = {
		M.Tr("dlg_mods_header_fmt", targetMeta.display, targetMeta.code, M.TextCacheCount, M.IdMapCount),
	}

	for idx, r in ipairs(reports) do
		local doneCount = 0
		local sameLang = (M.NormalizeLangGroup(r.sourceLang.code) == M.NormalizeLangGroup(targetMeta.code))
		if sameLang then
			doneCount = r.totalCount
		else
			for _, e in ipairs(r.entries) do
				if M.ActiveIdMap[e.key] or M.ActiveTextCache[e.sourceText] then
					doneCount = doneCount + 1
				end
			end
		end
		local pct = r.totalCount > 0 and math.floor((doneCount * 100) / r.totalCount) or 100
		local stateTag = sameLang and M.Tr("dlg_mods_native_lang") or string.format("%d/%d (%d%%)", doneCount, r.totalCount, pct)
		local activeTag = r.isActive and M.Tr("state_active") or M.Tr("state_inactive")
		lines[#lines + 1] = M.Tr("dlg_mods_item_fmt", idx, r.title, activeTag, r.sourceLang.display, stateTag)
	end

	return table.concat(lines, "\n")
end

function M.OpenControlMenu()
	if M.MenuOpen then return end
	local createThread = rawget(_ENV, "CreateRealTimeThread")
	if not createThread then return end

	createThread(function()
		if M.MenuOpen then return end
		M.MenuOpen = true

		local waitList = rawget(_ENV, "WaitListChoice")
		local waitInput = rawget(_ENV, "WaitInputText")
		local term = rawget(_ENV, "terminal")
		local desktop = term and term.desktop

		if not waitList or not desktop then
			M.MenuOpen = false
			return
		end

		while true do
			local s = M.LoadSettings()
			local provMeta = M.GetProviderMeta(s.provider)
			local targetMeta = M.ResolveLanguage(s.targetLanguage)
			local apiKey = M.GetActiveApiKey(s)
			local model = M.GetActiveModel(s)
			local liveStatus = (M.GetLiveStatusText and M.GetLiveStatusText()) or M.LiveStatusLine or M.Tr("state_idle")
			local tierSummary = M.FormatTierSummary(s)

			local runActionLabel
			if M.IsTranslating then
				runActionLabel = M.Tr("menu_1_pause_fmt", liveStatus)
			else
				runActionLabel = M.Tr("menu_1_start")
			end

			local statusLabel = M.Tr("menu_2_status_fmt", liveStatus, M.TextCacheCount)
			local keyLabel = M.Tr("menu_3_key_fmt", mask_api_key(apiKey))
			local provLabel = M.Tr("menu_4_prov_fmt", provMeta.name)
			local modelLabel = M.Tr("menu_5_model_fmt", model)
			local langLabel = M.Tr("menu_6_lang_fmt", M.FormatTargetLangSetting(s.targetLanguage), targetMeta.display)
			local quotaLabel = M.Tr("menu_7_quota_fmt", tierSummary)
			local modsLabel = M.Tr("menu_8_mods")
			local hudStateText = (s.showHudBanner ~= false) and M.Tr("state_on") or M.Tr("state_hidden")
			local hudLabel = M.Tr("menu_9_hud_fmt", hudStateText)
			local descStateText = (s.translateModDescriptions ~= false) and M.Tr("state_on") or M.Tr("state_inactive")
			local descLabel = M.Tr("menu_desc_fmt", descStateText)
			local retranslateLabel = M.Tr("menu_11_retranslate")
			local closeLabel = M.Tr("menu_0_close")

			local choices = {
				runActionLabel,
				statusLabel,
				keyLabel,
				provLabel,
				modelLabel,
				langLabel,
				quotaLabel,
				modsLabel,
				hudLabel,
				descLabel,
				retranslateLabel,
				closeLabel,
			}

			local picked = waitList(
				desktop,
				choices,
				M.Tr("panel_title_fmt", M.Version),
				choices[1],
				12,
				false,
				"idJA3TradutorIAMenu"
			)

			if not picked or picked == closeLabel then
				break
			elseif picked == runActionLabel then
				if M.IsTranslating then
					M.StopBackgroundTranslation("status_paused_user")
				else
					M.StartBackgroundTranslation(true)
				end
			elseif picked == statusLabel then
				show_info_box(
					M.Tr("dlg_status_title"),
					M.Tr(
						"dlg_status_body_fmt",
						liveStatus,
						provMeta.name,
						model,
						mask_api_key(apiKey),
						tierSummary,
						tonumber(s.batchSize) or 35,
						tonumber(s.minDelayMs) or 1500,
						targetMeta.display,
						targetMeta.code,
						M.TextCacheCount,
						M.IdMapCount
					)
				)
			elseif picked == keyLabel then
				if waitInput then
					local placeholder = M.Tr("dlg_key_placeholder")
					local initialText = apiKey ~= "" and apiKey or placeholder
					local entered = waitInput(
						desktop,
						M.Tr("dlg_key_title_fmt", provMeta.name),
						initialText,
						512,
						nil,
						"idJA3TradutorIAKeyInput",
						M.Tr("dlg_key_desc_fmt", provMeta.name)
					)
					if entered ~= nil then
						local cleanKey = M.Trim(entered)
						if cleanKey == placeholder or cleanKey == "Text..." then
							cleanKey = ""
						end
						M.SetActiveApiKey(cleanKey, s.provider)
						if cleanKey ~= "" then
							M.UpdateHudBanner(M.Tr("hud_validating_key_title"), M.Tr("hud_validating_key_detail"), 15, nil)
							local tierInfo = M.DetectAndTuneTier(M.LoadSettings(), true)
							show_info_box(
								M.Tr("dlg_key_saved_title"),
								M.Tr(
									"dlg_key_saved_body_fmt",
									provMeta.name,
									mask_api_key(cleanKey),
									M.FormatTierSummary(M.LoadSettings()),
									tierInfo.ok and M.Tr("dlg_key_saved_ok") or M.Tr("dlg_key_saved_check")
								)
							)
							if tierInfo.ok then
								M.StartBackgroundTranslation(true)
							end
						end
					end
				end
			elseif picked == provLabel then
				local provItems = {}
				local mapChoiceToProv = {}
				local currentChoice = nil
				for _, pid in ipairs(M.ProviderOrder) do
					local pm = M.Providers[pid]
					local label = pid .. " — " .. pm.name .. (pm.requiresKey and "" or M.Tr("provider_no_key_tag"))
					provItems[#provItems + 1] = label
					mapChoiceToProv[label] = pid
					if pid == s.provider then currentChoice = label end
				end
				local selProvLabel = waitList(desktop, provItems, M.Tr("dlg_prov_title"), currentChoice, 10, false, "idJA3TradutorIAProv")
				local newProv = selProvLabel and mapChoiceToProv[selProvLabel]
				if newProv and newProv ~= s.provider then
					s.provider = newProv
					s.apiKey = (type(s.apiKeys) == "table" and s.apiKeys[newProv]) or ""
					s.model = (type(s.models) == "table" and s.models[newProv]) or M.Providers[newProv].defaultModel
					s.tierSignature = ""
					sync_option_to_engine("AiProvider", newProv)
					if newProv == "custom" and waitInput then
						local ep = waitInput(
							desktop,
							M.Tr("dlg_endpoint_title"),
							s.customEndpoint or "http://localhost:8000/v1",
							512,
							nil,
							"idJA3TradutorIAEp",
							M.Tr("dlg_endpoint_desc")
						)
						if ep and M.Trim(ep) ~= "" then
							s.customEndpoint = M.Trim(ep)
						end
					end
					M.SaveSettings()
					M.DetectAndTuneTier(s, true)
				end
			elseif picked == modelLabel then
				M.UpdateHudBanner(
					M.Tr("hud_fetching_models_title"),
					M.Tr("hud_fetching_models_detail_fmt", provMeta.name),
					20,
					4000
				)
				local modelList = M.FetchAvailableModels(s)
				local selModel = waitList(
					desktop,
					modelList,
					M.Tr("dlg_model_title_fmt", provMeta.name),
					model,
					15,
					true,
					"idJA3TradutorIAModel"
				)
				if selModel and M.Trim(selModel) ~= "" then
					sync_option_to_engine("AiModelPreset", "auto")
					M.SetActiveModel(M.Trim(selModel), s.provider)
					M.DetectAndTuneTier(M.LoadSettings(), true)
					if s.autoTranslate ~= false then
						M.StartBackgroundTranslation(true)
					end
				end
			elseif picked == langLabel then
				local autoLabel = M.Tr("opt_choice_auto_lang")
				local langChoices = { autoLabel }
				for _, l in ipairs(M.Languages) do
					langChoices[#langChoices + 1] = l.display
				end
				local currentLangDisplay = M.IsAutoTargetLang(s.targetLanguage) and autoLabel or s.targetLanguage
				local selLangLabel = waitList(desktop, langChoices, M.Tr("dlg_lang_title"), currentLangDisplay, 16, false, "idJA3TradutorIALang")
				if selLangLabel then
					local canonicalLang = (selLangLabel == autoLabel) and "auto" or selLangLabel
					if canonicalLang ~= s.targetLanguage then
						s.targetLanguage = canonicalLang
						sync_option_to_engine("TargetLanguage", canonicalLang)
						M.SaveSettings()
						M.StopBackgroundTranslation("status_switching_lang")
						local newMeta = M.ResolveLanguage(canonicalLang)
						M.LoadLanguageDatabases(newMeta.code, true)
						M.ApplySavedTranslationsToMemory(true)
						M.StartBackgroundTranslation(true)
					end
				end
			elseif picked == quotaLabel then
				M.UpdateHudBanner(M.Tr("hud_testing_api_title"), M.Tr("hud_testing_api_detail"), 35, 5000)
				M.DetectAndTuneTier(s, true)
				show_info_box(
					M.Tr("dlg_quota_title"),
					M.Tr(
						"dlg_quota_body_fmt",
						provMeta.name,
						M.GetActiveModel(s),
						M.FormatTierSummary(s),
						tonumber(s.batchSize) or 35,
						tonumber(s.minDelayMs) or 1500
					)
				)
			elseif picked == modsLabel then
				show_info_box(M.Tr("dlg_mods_title"), build_mods_report_text())
			elseif picked == hudLabel then
				s.showHudBanner = not (s.showHudBanner ~= false)
				sync_option_to_engine("ShowHudBanner", s.showHudBanner)
				M.SaveSettings()
				if not s.showHudBanner then
					M.DestroyHudBanner()
				else
					M.UpdateHudBanner(M.Tr("hud_enabled_title"), M.Tr("hud_enabled_detail"), 100, 3500)
				end
			elseif picked == descLabel then
				s.translateModDescriptions = not (s.translateModDescriptions ~= false)
				sync_option_to_engine("TranslateModDescriptions", s.translateModDescriptions)
				M.SaveSettings()
				M.ApplyModUiLocalization()
				if s.translateModDescriptions and s.autoTranslate ~= false then
					M.StartBackgroundTranslation(true)
				end
			elseif picked == retranslateLabel then
				if ask_yes_no(
					M.Tr("dlg_retranslate_title"),
					M.Tr("dlg_retranslate_confirm_fmt", targetMeta.display)
				) then
					M.StopBackgroundTranslation("status_clearing_cache")
					M.ClearLanguageCache(targetMeta.code, true)
					M.StartBackgroundTranslation(true)
				else
					M.StartBackgroundTranslation(true)
				end
			end
		end

		M.MenuOpen = false
	end)
end

-- ============================================================================
-- Registro do Atalho Global (Ctrl+Shift+T) e Botões nos Menus do JA3
-- ============================================================================

function M.RegisterShortcutsAndMenuButtons()
	-- 1. Atalho global Ctrl+Shift+T / Ctrl+Alt+T via TerminalTarget
	local term = rawget(_ENV, "terminal")
	local termTargetCls = rawget(_ENV, "TerminalTarget")
	if term and termTargetCls and not M.ShortcutTarget then
		local target = termTargetCls:new({
			terminal_target_priority = 500000,
			OnShortcut = function(self, shortcut, source, ...)
				if shortcut == "Ctrl-Shift-T" or shortcut == "Ctrl-Alt-T" then
					if not M.MenuOpen then
						M.OpenControlMenu()
						return "break"
					end
				end
			end,
		})
		if type(term.AddTarget) == "function" then
			term.AddTarget(target)
		end
		M.ShortcutTarget = target
	end

	-- 2. Garante que a tela inicial que abre o jogo (PGMainActions) permaneça 100% limpa/original
	local xTemplates = rawget(_ENV, "XTemplates")
	if type(xTemplates) == "table" then
		local pgTpl = xTemplates["PGMainActions"]
		local pgContainer = type(pgTpl) == "table" and pgTpl[1]
		if type(pgContainer) == "table" then
			for i = #pgContainer, 1, -1 do
				if type(pgContainer[i]) == "table" and pgContainer[i].ActionId == "idJA3TradutorIA" then
					table.remove(pgContainer, i)
				end
			end
		end
	end

	-- 3. Injeta/atualiza o botão localizado apenas no Gerenciador de Mods e no Menu de Pausa em jogo
	local placeObj = rawget(_ENV, "PlaceObj")
	local untranslated = rawget(_ENV, "Untranslated")
	if type(xTemplates) ~= "table" or type(placeObj) ~= "function" or type(untranslated) ~= "function" then
		return
	end

	local btnLabel = untranslated(M.Tr("menu_button"))
	local targetMenus = { "ModManagerActions", "IGMainActions" }
	for _, tplName in ipairs(targetMenus) do
		local tpl = xTemplates[tplName]
		local container = type(tpl) == "table" and tpl[1]
		if type(container) == "table" then
			local existingAction = nil
			for _, child in ipairs(container) do
				if type(child) == "table" and child.ActionId == "idJA3TradutorIA" then
					existingAction = child
					break
				end
			end
			if existingAction then
				existingAction.ActionName = btnLabel
			else
				container[#container + 1] = placeObj("XTemplateAction", {
					"ActionId", "idJA3TradutorIA",
					"ActionName", btnLabel,
					"ActionToolbar", "mainmenu",
					"FXPress", "MainMenuButtonClick",
					"OnAction", function(self, host, source, ...)
						M.OpenControlMenu()
					end,
				})
			end
		end
	end
end
