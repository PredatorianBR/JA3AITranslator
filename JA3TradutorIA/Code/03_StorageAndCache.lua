-- ============================================================================
-- JA3 Tradutor IA - 03_StorageAndCache.lua
-- Persistência automática em disco (AppData/JA3TradutorIA), cache por texto e
-- injeção instantânea em memória (TranslationTable + ModItemOption + UI Live).
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

M.SettingsPath = M.DataDir .. "/settings.json"
M.Settings = M.Settings or nil
M.LoadedLangCode = M.LoadedLangCode or nil
M.ActiveTextCache = M.ActiveTextCache or {}
M.ActiveIdMap = M.ActiveIdMap or {}
M.TranslatedModDescriptions = M.TranslatedModDescriptions or {}
M.TextCacheCount = M.TextCacheCount or 0
M.IdMapCount = M.IdMapCount or 0

local function count_keys(t)
	if type(t) ~= "table" then return 0 end
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

function M.EnsureDataDir()
	if M.AsyncCreatePath then
		M.AsyncCreatePath(M.DataDir)
	end
end

function M.ReadJsonFile(path)
	if not M.AsyncFileToString then return nil, "Bridge indisponivel" end
	local err, content = M.AsyncFileToString(path)
	if err or not content or content == "" then
		return nil, tostring(err or "vazio")
	end
	return M.JsonDecode(content)
end

function M.WriteJsonFile(path, tbl, forceObject)
	if not M.AsyncStringToFile then return "Bridge indisponivel" end
	M.EnsureDataDir()
	if forceObject and type(tbl) == "table" then
		M.JsonObject(tbl)
	end
	local encoded = M.JsonEncode(tbl)
	return M.AsyncStringToFile(path, encoded)
end

function M.DefaultSettings()
	return {
		provider = "gemini",
		apiKey = "",
		apiKeys = { gemini = "" },
		model = "gemini-2.5-flash-lite",
		models = { gemini = "gemini-2.5-flash-lite" },
		customEndpoint = "http://localhost:8000/v1",
		targetLanguage = "auto",
		autoTranslate = true,
		scanScope = "active",
		translateModDescriptions = true,
		autoTuneQuota = true,
		showHudBanner = true,
		detectedTier = "unknown",
		detectedTierSummary = "",
		tierSignature = "",
		batchSize = 35,
		minDelayMs = 1500,
		maxCharsPerBatch = 7500,
	}
end

function M.GetActiveApiKey(settings)
	local s = settings or M.Settings or M.DefaultSettings()
	local prov = string.lower(tostring(s.provider or "gemini"))
	if type(s.apiKeys) == "table" and type(s.apiKeys[prov]) == "string" and s.apiKeys[prov] ~= "" then
		return M.Trim(s.apiKeys[prov])
	end
	if type(s.apiKey) == "string" and s.apiKey ~= "" then
		return M.Trim(s.apiKey)
	end
	return ""
end

function M.SetActiveApiKey(key, providerOverride)
	local s = M.LoadSettings()
	local prov = string.lower(tostring(providerOverride or s.provider or "gemini"))
	local clean = M.Trim(tostring(key or ""))
	s.apiKeys = type(s.apiKeys) == "table" and s.apiKeys or {}
	s.apiKeys[prov] = clean
	if prov == string.lower(tostring(s.provider or "gemini")) then
		s.apiKey = clean
	end
	s.tierSignature = "" -- Força nova detecção Free vs Paga para a nova chave
	M.SaveSettings()
end

function M.GetActiveModel(settings)
	local s = settings or M.Settings or M.DefaultSettings()
	local prov = string.lower(tostring(s.provider or "gemini"))
	local meta = M.GetProviderMeta(prov)
	if type(s.model) == "string" and M.Trim(s.model) ~= "" then
		return M.Trim(s.model)
	end
	if type(s.models) == "table" and type(s.models[prov]) == "string" and M.Trim(s.models[prov]) ~= "" then
		return M.Trim(s.models[prov])
	end
	return meta.defaultModel
end

function M.SetActiveModel(modelName, providerOverride)
	local s = M.LoadSettings()
	local prov = string.lower(tostring(providerOverride or s.provider or "gemini"))
	local clean = M.Trim(tostring(modelName or ""))
	if clean == "" then return end
	s.models = type(s.models) == "table" and s.models or {}
	s.models[prov] = clean
	if prov == string.lower(tostring(s.provider or "gemini")) then
		s.model = clean
	end
	s.tierSignature = "" -- Recalibra lote/intervalo para o novo modelo (ex: flash-lite vs flash vs pro)
	M.SaveSettings()
end

function M.LoadSettings()
	if M.Settings then
		return M.Settings
	end

	local defaults = M.DefaultSettings()
	local disk = M.ReadJsonFile(M.SettingsPath)

	-- Fallback secundário via CurrentModStorageTable caso o arquivo JSON não exista ainda
	if type(disk) ~= "table" then
		local modStorage = rawget(_ENV, "CurrentModStorageTable")
		if type(modStorage) == "table" and type(modStorage.settingsBackup) == "table" then
			disk = modStorage.settingsBackup
		end
	end

	if type(disk) == "table" then
		for k, v in pairs(disk) do
			if v ~= nil then
				defaults[k] = v
			end
		end
	end

	defaults.apiKeys = type(defaults.apiKeys) == "table" and defaults.apiKeys or {}
	defaults.models = type(defaults.models) == "table" and defaults.models or {}

	local prov = string.lower(tostring(defaults.provider or "gemini"))
	defaults.provider = prov
	if type(defaults.apiKey) == "string" and defaults.apiKey ~= "" and (not defaults.apiKeys[prov] or defaults.apiKeys[prov] == "") then
		defaults.apiKeys[prov] = M.Trim(defaults.apiKey)
	elseif type(defaults.apiKeys[prov]) == "string" and defaults.apiKeys[prov] ~= "" and (not defaults.apiKey or defaults.apiKey == "") then
		defaults.apiKey = M.Trim(defaults.apiKeys[prov])
	end

	if type(defaults.model) == "string" and defaults.model ~= "" and (not defaults.models[prov] or defaults.models[prov] == "") then
		defaults.models[prov] = M.Trim(defaults.model)
	end

	M.Settings = defaults
	return M.Settings
end

function M.SaveSettings()
	if not M.Settings then return end
	M.JsonObject(M.Settings.apiKeys)
	M.JsonObject(M.Settings.models)
	M.WriteJsonFile(M.SettingsPath, M.Settings, true)

	-- Salva backup compacto também no CurrentModStorageTable (limite 32 KB)
	local modStorage = rawget(_ENV, "CurrentModStorageTable")
	local writeModStorage = rawget(_ENV, "WriteModPersistentStorageTable")
	if type(modStorage) == "table" and type(writeModStorage) == "function" then
		modStorage.settingsBackup = {
			provider = M.Settings.provider,
			apiKey = M.Settings.apiKey,
			apiKeys = M.Settings.apiKeys,
			model = M.Settings.model,
			models = M.Settings.models,
			customEndpoint = M.Settings.customEndpoint,
			targetLanguage = M.Settings.targetLanguage,
			translateModDescriptions = M.Settings.translateModDescriptions,
			detectedTier = M.Settings.detectedTier,
			detectedTierSummary = M.Settings.detectedTierSummary,
			tierSignature = M.Settings.tierSignature,
			batchSize = M.Settings.batchSize,
			minDelayMs = M.Settings.minDelayMs,
			maxCharsPerBatch = M.Settings.maxCharsPerBatch,
		}
		pcall(writeModStorage)
	end
end

-- Sincroniza as opções nativas do menu Opções de Mods do JA3 com M.Settings
function M.SyncFromModOptions()
	local s = M.LoadSettings()
	local opts = rawget(_ENV, "CurrentModOptions")
	if not opts then
		return s, false
	end

	local changed = false
	local prevLang = M.ResolveLanguage(s.targetLanguage).code

	local optAuto = opts.AutoTranslate
	if optAuto ~= nil and s.autoTranslate ~= optAuto then
		s.autoTranslate = optAuto
		changed = true
	end

	local optTarget = opts.TargetLanguage
	if type(optTarget) == "string" and optTarget ~= "" then
		local normTarget = M.IsAutoTargetLang(optTarget) and "auto" or optTarget
		-- Se settings já veio migrado com idioma explícito e ModOptions nunca foi alterado pelo usuário (ainda no default "auto" inicial),
		-- sincronizamos CurrentModOptions na primeira carga caso AccountStorage não tenha gravado override.
		if s.targetLanguage ~= normTarget then
			s.targetLanguage = normTarget
			changed = true
		end
	end

	local optProv = opts.AiProvider
	if type(optProv) == "string" and optProv ~= "" then
		local lowProv = string.lower(optProv)
		if s.provider ~= lowProv and M.Providers[lowProv] then
			s.provider = lowProv
			s.apiKey = (type(s.apiKeys) == "table" and s.apiKeys[lowProv]) or ""
			local savedModel = (type(s.models) == "table" and s.models[lowProv]) or M.Providers[lowProv].defaultModel
			s.model = savedModel
			s.tierSignature = ""
			changed = true
		end
	end

	local optModel = opts.AiModelPreset
	if type(optModel) == "string" and not M.IsAutoModelPreset(optModel) then
		if s.model ~= optModel then
			s.model = optModel
			s.models[s.provider] = optModel
			s.tierSignature = ""
			changed = true
		end
	end

	local optScope = opts.ScanScope
	if type(optScope) == "string" and optScope ~= "" then
		local normScope = M.IsAllModsScope(optScope) and "all" or "active"
		if s.scanScope ~= normScope then
			s.scanScope = normScope
			changed = true
		end
	end

	local optDesc = opts.TranslateModDescriptions
	if optDesc ~= nil and s.translateModDescriptions ~= optDesc then
		s.translateModDescriptions = optDesc
		changed = true
	end

	local optTune = opts.AutoTuneQuota
	if optTune ~= nil and s.autoTuneQuota ~= optTune then
		s.autoTuneQuota = optTune
		s.tierSignature = ""
		changed = true
	end

	local optHud = opts.ShowHudBanner
	if optHud ~= nil and s.showHudBanner ~= optHud then
		s.showHudBanner = optHud
		changed = true
	end

	if changed then
		M.SaveSettings()
	end

	local newLang = M.ResolveLanguage(s.targetLanguage).code
	return s, (prevLang ~= newLang)
end

-- ============================================================================
-- Cache de Traduções por Idioma (cache_<lang>.json + id_map_<lang>.json)
-- ============================================================================

function M.GetCacheFilePath(langCode)
	return M.DataDir .. "/cache_" .. tostring(langCode) .. ".json"
end

function M.GetIdMapFilePath(langCode)
	return M.DataDir .. "/id_map_" .. tostring(langCode) .. ".json"
end

function M.LoadLanguageDatabases(langCode, forceReload)
	langCode = langCode or M.ResolveLanguage(M.LoadSettings().targetLanguage).code
	if not forceReload and M.LoadedLangCode == langCode then
		return M.ActiveIdMap, M.ActiveTextCache
	end

	local textCache = M.ReadJsonFile(M.GetCacheFilePath(langCode))
	if type(textCache) ~= "table" then
		textCache = {}
	end

	local idMap = M.ReadJsonFile(M.GetIdMapFilePath(langCode))
	if type(idMap) ~= "table" then
		idMap = {}
	end

	M.LoadedLangCode = langCode
	M.ActiveTextCache = textCache
	M.ActiveIdMap = idMap
	M.TextCacheCount = count_keys(textCache)
	M.IdMapCount = count_keys(idMap)
	M.TranslatedModDescriptions = {}
	for k, v in pairs(idMap) do
		if type(k) == "string" and k:sub(1, 5) == "desc|" and type(v) == "string" and v ~= "" then
			M.TranslatedModDescriptions[k:sub(6)] = v
		end
	end

	M.Log("Banco de traducoes carregado (%s): %d textos em cache, %d IDs mapeados.",
		langCode, M.TextCacheCount, M.IdMapCount)
	return M.ActiveIdMap, M.ActiveTextCache
end

function M.RefreshGameUiTexts()
	local clearStyle = rawget(_ENV, "ClearTextStyleCache")
	if type(clearStyle) == "function" then
		pcall(clearStyle)
	end
	local term = rawget(_ENV, "terminal")
	local desktop = term and term.desktop
	local recUpdate = rawget(_ENV, "RecursiveUpdateTTexts")
	if desktop and type(recUpdate) == "function" then
		pcall(recUpdate, desktop)
	end
	local objMod = rawget(_ENV, "ObjModified")
	if type(objMod) == "function" then
		pcall(objMod, "PreGameButtons")
	end
end

-- Aplica uma chave "opt|<modId>|<optName>|<field>" nas ModItemOption carregadas
local function apply_mod_option_entry(modsDict, key, translatedText)
	if type(modsDict) ~= "table" then return false end
	local modId, optName, field = key:match("^opt|([^|]+)|([^|]+)|([^|]+)$")
	if not modId or not optName or (field ~= "DisplayName" and field ~= "Help") then
		return false
	end
	local modDef = modsDict[modId]
	if not modDef or type(modDef.items) ~= "table" then
		return false
	end
	local updated = false
	for _, item in ipairs(modDef.items) do
		if type(item) == "table" and item.name == optName then
			local origField = "__ja3tr_orig_" .. field
			if rawget(item, origField) == nil and type(item[field]) == "string" then
				rawset(item, origField, item[field])
			end
			if item[field] ~= translatedText then
				item[field] = translatedText
				updated = true
			end
		end
	end
	if updated and type(modDef.options) == "table" then
		modDef.options.properties = nil
	end
	return updated
end

-- Injeta todas as traduções salvas em memória (TranslationTable + ModOptions)
function M.ApplySavedTranslationsToMemory(refreshUi)
	local s = M.LoadSettings()
	local langCode = M.ResolveLanguage(s.targetLanguage).code
	local idMap = M.LoadLanguageDatabases(langCode, false)

	local transTable = rawget(_ENV, "TranslationTable")
	if type(transTable) ~= "table" then
		return 0
	end

	local modsDict = rawget(_ENV, "Mods")
	local appliedCount = 0

	for k, v in pairs(idMap) do
		if type(v) == "string" and v ~= "" then
			local numId = tonumber(k)
			if numId then
				if transTable[numId] ~= v then
					transTable[numId] = v
					appliedCount = appliedCount + 1
				end
			elseif type(k) == "string" and k:sub(1, 4) == "opt|" then
				if apply_mod_option_entry(modsDict, k, v) then
					appliedCount = appliedCount + 1
				end
			elseif type(k) == "string" and k:sub(1, 5) == "desc|" then
				local modId = k:sub(6)
				M.TranslatedModDescriptions[modId] = v
				appliedCount = appliedCount + 1
			end
		end
	end

	if refreshUi and appliedCount > 0 then
		M.RefreshGameUiTexts()
	end

	return appliedCount
end

-- Aplica e persiste imediatamente um lote recém-traduzido (ou recuperado do cache)
function M.CommitBatchTranslations(langCode, newIdPairs, newTextPairs, refreshUi)
	M.LoadLanguageDatabases(langCode, false)

	local transTable = rawget(_ENV, "TranslationTable")
	local modsDict = rawget(_ENV, "Mods")
	local idDirty = false
	local textDirty = false

	if type(newTextPairs) == "table" then
		for srcText, dstText in pairs(newTextPairs) do
			if type(srcText) == "string" and srcText ~= "" and type(dstText) == "string" and dstText ~= "" then
				if M.ActiveTextCache[srcText] == nil then
					M.TextCacheCount = M.TextCacheCount + 1
				end
				if M.ActiveTextCache[srcText] ~= dstText then
					M.ActiveTextCache[srcText] = dstText
					textDirty = true
				end
			end
		end
	end

	if type(newIdPairs) == "table" then
		for idKey, dstText in pairs(newIdPairs) do
			local keyStr = tostring(idKey)
			if keyStr ~= "" and type(dstText) == "string" and dstText ~= "" then
				if M.ActiveIdMap[keyStr] == nil then
					M.IdMapCount = M.IdMapCount + 1
				end
				if M.ActiveIdMap[keyStr] ~= dstText then
					M.ActiveIdMap[keyStr] = dstText
					idDirty = true
				end

				local numId = tonumber(keyStr)
				if numId and type(transTable) == "table" then
					transTable[numId] = dstText
				elseif keyStr:sub(1, 4) == "opt|" then
					apply_mod_option_entry(modsDict, keyStr, dstText)
				elseif keyStr:sub(1, 5) == "desc|" then
					M.TranslatedModDescriptions[keyStr:sub(6)] = dstText
				end
			end
		end
	end

	if idDirty then
		M.WriteJsonFile(M.GetIdMapFilePath(langCode), M.ActiveIdMap, true)
	end
	if textDirty then
		M.WriteJsonFile(M.GetCacheFilePath(langCode), M.ActiveTextCache, true)
	end
	if refreshUi and (idDirty or textDirty) then
		M.RefreshGameUiTexts()
	end

	return idDirty or textDirty
end

-- Limpa o mapeamento de IDs do idioma atual (mantendo ou limpando o cache de textos)
function M.ClearLanguageCache(langCode, clearTextCacheToo)
	langCode = langCode or M.ResolveLanguage(M.LoadSettings().targetLanguage).code
	M.LoadLanguageDatabases(langCode, false)

	-- Restaura textos originais de ModItemOption antes de limpar
	local modsDict = rawget(_ENV, "Mods")
	if type(modsDict) == "table" then
		for _, modDef in pairs(modsDict) do
			if type(modDef) == "table" and type(modDef.items) == "table" then
				for _, item in ipairs(modDef.items) do
					if type(item) == "table" then
						local origDisp = rawget(item, "__ja3tr_orig_DisplayName")
						if origDisp ~= nil then item.DisplayName = origDisp end
						local origHelp = rawget(item, "__ja3tr_orig_Help")
						if origHelp ~= nil then item.Help = origHelp end
					end
				end
			end
		end
	end

	M.ActiveIdMap = {}
	M.IdMapCount = 0
	M.WriteJsonFile(M.GetIdMapFilePath(langCode), M.ActiveIdMap, true)

	if clearTextCacheToo then
		M.ActiveTextCache = {}
		M.TextCacheCount = 0
		M.WriteJsonFile(M.GetCacheFilePath(langCode), M.ActiveTextCache, true)
	end
end
