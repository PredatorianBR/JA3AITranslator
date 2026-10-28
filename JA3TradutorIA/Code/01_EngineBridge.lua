-- ============================================================================
-- JA3 Tradutor IA - 01_EngineBridge.lua
-- Ponte nativa 100% Lua com o motor C++ do Jagged Alliance 3 (sem .exe externo)
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

M.Version = "2.2.0"
M.DataDir = "AppData/JA3TradutorIA"

-- Obtém as primitivas assíncronas nativas (libcurl HTTPS + VFS AppData/HPK) do JA3.exe
local bridge_err, fnWebReq, fnFileToStr, fnStrToFile, fnListFiles, fnCreatePath =
	LuaCodeToTuple("AsyncWebRequest, AsyncFileToString, AsyncStringToFile, AsyncListFiles, AsyncCreatePath")

M.BridgeError = bridge_err
M.AsyncWebRequest = fnWebReq
M.AsyncFileToString = fnFileToStr
M.AsyncStringToFile = fnStrToFile
M.AsyncListFiles = fnListFiles
M.AsyncCreatePath = fnCreatePath

function M.Log(fmt, ...)
	local msg
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, tostring(fmt), ...)
		msg = ok and formatted or tostring(fmt)
	else
		msg = tostring(fmt)
	end
	local line = "[JA3TradutorIA] " .. msg
	local dbg = rawget(_ENV, "DebugPrint")
	if dbg then
		dbg(line .. "\n")
	else
		print(line)
	end
end

function M.Trim(s)
	if type(s) ~= "string" then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ============================================================================
-- Serializador JSON determinístico (suporta objetos {} vs arrays [] explícitos)
-- ============================================================================

local JSON_ARRAY_TAG = {}
local JSON_OBJECT_TAG = {}

function M.JsonArray(t)
	t = t or {}
	rawset(t, JSON_ARRAY_TAG, true)
	return t
end

function M.JsonObject(t)
	t = t or {}
	rawset(t, JSON_OBJECT_TAG, true)
	return t
end

local json_escapes = {
	['"']  = '\\"',
	['\\'] = '\\\\',
	['\b'] = '\\b',
	['\f'] = '\\f',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t',
}

for b = 0, 31 do
	local ch = string.char(b)
	if not json_escapes[ch] then
		json_escapes[ch] = string.format("\\u%04x", b)
	end
end

function M.JsonEscape(s)
	if s == nil then return "" end
	return (tostring(s):gsub('[%z\1-\31\\"]', json_escapes))
end

local function is_json_array(t)
	if rawget(t, JSON_ARRAY_TAG) then return true end
	if rawget(t, JSON_OBJECT_TAG) then return false end
	local count = 0
	for k, v in pairs(t) do
		if k ~= JSON_ARRAY_TAG and k ~= JSON_OBJECT_TAG then
			if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
				return false
			end
			count = count + 1
		end
	end
	if count == 0 then
		return false -- tabelas vazias sem marcador viram "{}"
	end
	return count == #t
end

local function encode_value(val, depth)
	if depth > 32 then return "null" end
	local vt = type(val)
	if val == nil then
		return "null"
	elseif vt == "boolean" then
		return val and "true" or "false"
	elseif vt == "number" then
		if val ~= val or val >= math.huge or val <= -math.huge then
			return "0"
		end
		if math.type and math.type(val) == "integer" then
			return tostring(val)
		end
		return tostring(val)
	elseif vt == "string" then
		return '"' .. M.JsonEscape(val) .. '"'
	elseif vt == "table" then
		if is_json_array(val) then
			local n = #val
			if n == 0 then return "[]" end
			local parts = {}
			for i = 1, n do
				parts[i] = encode_value(val[i], depth + 1)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			local parts = {}
			local keys = {}
			for k in pairs(val) do
				if k ~= JSON_ARRAY_TAG and k ~= JSON_OBJECT_TAG and val[k] ~= nil then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for i = 1, #keys do
				local k = keys[i]
				parts[#parts + 1] = '"' .. M.JsonEscape(tostring(k)) .. '":' .. encode_value(val[k], depth + 1)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

function M.JsonEncode(val)
	return encode_value(val, 0)
end

function M.JsonDecode(str)
	if type(str) ~= "string" or str == "" then
		return nil, "JSON vazio"
	end
	-- Remove UTF-8 BOM se presente
	if str:sub(1, 3) == "\239\187\191" then
		str = str:sub(4)
	end
	local jsonToLua = rawget(_ENV, "JSONToLua")
	if not jsonToLua then
		return nil, "JSONToLua indisponivel"
	end
	local ok, err_or_res, parsed = pcall(jsonToLua, str)
	if not ok then
		return nil, tostring(err_or_res)
	end
	if err_or_res then
		return nil, tostring(err_or_res)
	end
	return parsed, nil
end

-- Extrai o primeiro bloco JSON ({...} ou [...]) de uma resposta de IA caso venha com markdown ```json
function M.ExtractFirstJsonBlock(rawText, openChar, closeChar)
	if type(rawText) ~= "string" then return nil end
	local s = M.Trim(rawText)
	if s:sub(1, 3) == "```" then
		s = s:gsub("^```[%w_-]*%s*", ""):gsub("%s*```$", "")
		s = M.Trim(s)
	end
	local startIdx = s:find(openChar, 1, true)
	if not startIdx then return nil end
	local depth = 0
	local inString = false
	local escaped = false
	local bOpen = openChar:byte(1)
	local bClose = closeChar:byte(1)
	local bQuote = string.byte('"')
	local bSlash = string.byte('\\')
	for i = startIdx, #s do
		local b = s:byte(i)
		if inString then
			if escaped then
				escaped = false
			elseif b == bSlash then
				escaped = true
			elseif b == bQuote then
				inString = false
			end
		else
			if b == bQuote then
				inString = true
			elseif b == bOpen then
				depth = depth + 1
			elseif b == bClose then
				depth = depth - 1
				if depth == 0 then
					return s:sub(startIdx, i)
				end
			end
		end
	end
	return s:sub(startIdx)
end

-- ============================================================================
-- Catálogo de Idiomas e Provedores de IA
-- ============================================================================

M.Languages = {
	{ code = "pt-BR", display = "Português (Brasil)", promptName = "Portuguese (Brazil)", ja3Value = "Brazilian" },
	{ code = "pt-PT", display = "Português (Portugal)", promptName = "Portuguese (Portugal)", ja3Value = "Portuguese" },
	{ code = "es",    display = "Español",              promptName = "Spanish",               ja3Value = "Spanish" },
	{ code = "fr",    display = "Français",             promptName = "French",                ja3Value = "French" },
	{ code = "de",    display = "Deutsch",              promptName = "German",                ja3Value = "German" },
	{ code = "it",    display = "Italiano",             promptName = "Italian",               ja3Value = "Italian" },
	{ code = "pl",    display = "Polski",               promptName = "Polish",                ja3Value = "Polish" },
	{ code = "ru",    display = "Русский",              promptName = "Russian",               ja3Value = "Russian" },
	{ code = "uk",    display = "Українська",           promptName = "Ukrainian",             ja3Value = "Ukrainian" },
	{ code = "tr",    display = "Türkçe",               promptName = "Turkish",               ja3Value = "Turkish" },
	{ code = "ja",    display = "日本語",                 promptName = "Japanese",              ja3Value = "Japanese" },
	{ code = "ko",    display = "한국어",                 promptName = "Korean",                ja3Value = "Koreana" },
	{ code = "zh-CN", display = "简体中文",               promptName = "Simplified Chinese",    ja3Value = "Schinese" },
	{ code = "zh-TW", display = "繁體中文",               promptName = "Traditional Chinese",   ja3Value = "Tchinese" },
	{ code = "en",    display = "English",              promptName = "English",               ja3Value = "English" },
}

M.LangByCode = {}
M.LangByDisplay = {}
M.LangByJa3 = {}
for _, l in ipairs(M.Languages) do
	M.LangByCode[l.code] = l
	M.LangByCode[string.lower(l.code)] = l
	M.LangByDisplay[l.display] = l
	M.LangByJa3[l.ja3Value] = l
end
M.LangByJa3["Latam"] = M.LangByCode["es"]

function M.ResolveLanguage(choiceOrCode)
	local isAuto = (not choiceOrCode or choiceOrCode == "" or choiceOrCode == "auto"
		or choiceOrCode == "Auto (Idioma do Jogo)" or choiceOrCode == "Auto (Game Language)")
	if type(choiceOrCode) == "string" and not isAuto then
		local byDisp = M.LangByDisplay[choiceOrCode]
		if byDisp then return byDisp end
		local byCode = M.LangByCode[choiceOrCode] or M.LangByCode[string.lower(choiceOrCode)]
		if byCode then return byCode end
		local byJa3 = M.LangByJa3[choiceOrCode]
		if byJa3 then return byJa3 end
	end
	local getLang = rawget(_ENV, "GetLanguage")
	local gameLang = getLang and getLang() or "English"
	if M.LangByJa3[gameLang] then
		return M.LangByJa3[gameLang]
	end
	local allLangs = rawget(_ENV, "AllLanguages")
	if type(allLangs) == "table" then
		for _, entry in ipairs(allLangs) do
			if entry.value == gameLang and entry.locale then
				local found = M.LangByCode[entry.locale] or M.LangByCode[entry.locale:sub(1, 2)]
				if found then return found end
			end
		end
	end
	return M.LangByCode["en"]
end

function M.NormalizeLangGroup(code)
	if not code then return "" end
	local low = string.lower(code)
	if low:sub(1, 2) == "pt" then return "pt" end
	if low:sub(1, 2) == "zh" then return "zh" end
	if low:sub(1, 2) == "en" then return "en" end
	if low:sub(1, 2) == "es" then return "es" end
	return low
end

M.Providers = {
	gemini = {
		id = "gemini",
		name = "Google Gemini",
		requiresKey = true,
		defaultEndpoint = "https://generativelanguage.googleapis.com/v1beta",
		defaultModel = "gemini-2.5-flash-lite",
		models = {
			"gemini-2.5-flash-lite",
			"gemini-2.5-flash",
			"gemini-flash-lite-latest",
			"gemini-flash-latest",
			"gemini-2.5-pro",
			"gemini-2.0-flash",
		},
	},
	openai = {
		id = "openai",
		name = "OpenAI (ChatGPT)",
		requiresKey = true,
		defaultEndpoint = "https://api.openai.com/v1",
		defaultModel = "gpt-4.1-mini",
		models = { "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o-mini", "gpt-4.1", "gpt-4o" },
	},
	openrouter = {
		id = "openrouter",
		name = "OpenRouter",
		requiresKey = true,
		defaultEndpoint = "https://openrouter.ai/api/v1",
		defaultModel = "google/gemini-2.5-flash",
		models = {
			"google/gemini-2.5-flash",
			"openai/gpt-4o-mini",
			"meta-llama/llama-3.3-70b-instruct:free",
			"deepseek/deepseek-chat-v3-0324:free",
		},
	},
	groq = {
		id = "groq",
		name = "Groq",
		requiresKey = true,
		defaultEndpoint = "https://api.groq.com/openai/v1",
		defaultModel = "llama-3.3-70b-versatile",
		models = { "llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen/qwen3-32b" },
	},
	deepseek = {
		id = "deepseek",
		name = "DeepSeek",
		requiresKey = true,
		defaultEndpoint = "https://api.deepseek.com/v1",
		defaultModel = "deepseek-chat",
		models = { "deepseek-chat" },
	},
	ollama = {
		id = "ollama",
		name = "Ollama",
		requiresKey = false,
		defaultEndpoint = "http://localhost:11434/v1",
		defaultModel = "qwen2.5:7b",
		models = { "qwen2.5:7b", "llama3.1:8b", "gemma3:12b", "mistral:7b" },
	},
	lmstudio = {
		id = "lmstudio",
		name = "LM Studio",
		requiresKey = false,
		defaultEndpoint = "http://localhost:1234/v1",
		defaultModel = "local-model",
		models = { "local-model" },
	},
	custom = {
		id = "custom",
		name = "Custom OpenAI-Compatible",
		requiresKey = false,
		defaultEndpoint = "http://localhost:8000/v1",
		defaultModel = "gpt-4o-mini",
		models = { "gpt-4o-mini" },
	},
}

M.ProviderOrder = { "gemini", "openai", "openrouter", "groq", "deepseek", "ollama", "lmstudio", "custom" }

function M.GetProviderMeta(id)
	return M.Providers[string.lower(tostring(id or "gemini"))] or M.Providers.gemini
end
