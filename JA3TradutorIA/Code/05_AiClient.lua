-- ============================================================================
-- JA3 Tradutor IA - 05_AiClient.lua
-- Cliente HTTPS nativo (AsyncWebRequest/libcurl), Auto-Detector de Cota
-- Gratuita vs Paga, Listagem de Modelos e Tradutor em Lotes Resiliente.
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

M.LastApiCallRealTime = M.LastApiCallRealTime or 0

local function get_endpoint(settings)
	local prov = string.lower(tostring(settings.provider or "gemini"))
	if prov == "custom" and type(settings.customEndpoint) == "string" and M.Trim(settings.customEndpoint) ~= "" then
		return (M.Trim(settings.customEndpoint):gsub("/+$", ""))
	end
	local meta = M.GetProviderMeta(prov)
	return (meta.defaultEndpoint:gsub("/+$", ""))
end

function M.HttpRequest(opts)
	if not M.AsyncWebRequest then
		return { ok = false, status = 0, body = "", err = "AsyncWebRequest indisponivel" }
	end

	local req = {
		url = opts.url,
		method = opts.method or "GET",
		headers = opts.headers or {},
		timeout = opts.timeout or 90000,
		max_response_size = opts.maxResponseSize or (4 * 1024 * 1024),
	}
	if opts.body ~= nil then
		req.body = opts.body
	end

	local callOk, err, responseBody = pcall(M.AsyncWebRequest, req)
	if not callOk then
		return { ok = false, status = 0, body = "", err = tostring(err) }
	end

	if not err then
		return { ok = true, status = 200, body = tostring(responseBody or ""), err = nil }
	end

	if type(err) == "number" then
		return {
			ok = (err >= 200 and err < 300),
			status = err,
			body = tostring(responseBody or ""),
			err = "HTTP " .. tostring(err),
		}
	end

	return {
		ok = false,
		status = 0,
		body = tostring(responseBody or ""),
		err = tostring(err),
	}
end

-- Calibra tamanho de lote e delay em ms para Gemini Free Tier conforme a família do modelo
local function tune_gemini_free_for_model(modelName)
	local m = string.lower(tostring(modelName or ""))
	if m:find("lite", 1, true) then
		return 60, 4300, 9500
	elseif m:find("pro", 1, true) then
		return 65, 13000, 10000
	else
		return 55, 6500, 9000
	end
end

-- ============================================================================
-- Detecção Automática de Chave API Gratuita (Free Tier) vs Paga (Paid Tier)
-- ============================================================================

function M.DetectAndTuneTier(settings, forceRedetect)
	local s = settings or M.LoadSettings()
	local prov = string.lower(tostring(s.provider or "gemini"))
	local meta = M.GetProviderMeta(prov)
	local apiKey = M.GetActiveApiKey(s)
	local model = M.GetActiveModel(s)
	local endpoint = get_endpoint(s)

	local hashFn = rawget(_ENV, "xxhash")
	local keySig = hashFn and tostring(hashFn(apiKey)) or tostring(#apiKey)
	local sig = prov .. "|" .. keySig .. "|" .. model .. "|" .. tostring(s.autoTuneQuota ~= false)

	if not forceRedetect and s.tierSignature == sig and s.detectedTier and s.detectedTier ~= "unknown" then
		s.detectedTierSummary = M.FormatTierSummary(s)
		return {
			ok = (s.detectedTier ~= "invalid" and s.detectedTier ~= "missing_key"),
			tier = s.detectedTier,
			summary = s.detectedTierSummary,
			batchSize = s.batchSize,
			minDelayMs = s.minDelayMs,
		}
	end

	-- 1. Provedores locais / offline (Ollama, LM Studio, localhost)
	local isLocalUrl = endpoint:find("localhost", 1, true) ~= nil or endpoint:find("127.0.0.1", 1, true) ~= nil
	if prov == "ollama" or prov == "lmstudio" or (prov == "custom" and isLocalUrl) then
		s.detectedTier = "local"
		if s.autoTuneQuota ~= false then
			s.batchSize = 25
			s.minDelayMs = 0
			s.maxCharsPerBatch = 5500
		end
		s.detectedTierSummary = M.FormatTierSummary(s)
		s.tierSignature = sig
		M.SaveSettings()
		return { ok = true, tier = "local", summary = s.detectedTierSummary }
	end

	if meta.requiresKey and apiKey == "" then
		s.detectedTier = "missing_key"
		s.detectedTierSummary = M.FormatTierSummary(s)
		return { ok = false, missingKey = true, summary = s.detectedTierSummary }
	end

	-- 2. Google Gemini: Sonda de custo zero em gemini-2.5-flash-image (bloqueado com FreeTier em contas gratuitas)
	if prov == "gemini" then
		local probeUrl = endpoint .. "/models/gemini-2.5-flash-image:generateContent?key=" .. apiKey
		local probeBody = M.JsonEncode({
			contents = M.JsonArray({
				{
					parts = M.JsonArray({ { text = "ok" } }),
				},
			}),
			generationConfig = { maxOutputTokens = 1 },
		})

		local res = M.HttpRequest({
			url = probeUrl,
			method = "POST",
			headers = { ["Content-Type"] = "application/json" },
			body = probeBody,
			timeout = 20000,
		})

		local bodyLow = string.lower(res.body or "")
		if res.status == 400 or res.status == 401 or res.status == 403 then
			if bodyLow:find("api_key_invalid", 1, true) or bodyLow:find("api key not valid", 1, true) or res.status == 401 or res.status == 403 then
				s.detectedTier = "invalid"
				s.detectedTierSummary = M.FormatTierSummary(s)
				M.SaveSettings()
				return { ok = false, invalidKey = true, summary = s.detectedTierSummary }
			end
		end

		if res.status == 429 and (bodyLow:find("freetier", 1, true) or bodyLow:find("free_tier", 1, true) or bodyLow:find("limit: 0", 1, true)) then
			s.detectedTier = "free"
			local bSize, delayMs, maxChars = tune_gemini_free_for_model(model)
			if s.autoTuneQuota ~= false then
				s.batchSize = bSize
				s.minDelayMs = delayMs
				s.maxCharsPerBatch = maxChars
			end
			s.detectedTierSummary = M.FormatTierSummary(s)
			s.tierSignature = sig
			M.SaveSettings()
			M.Log("Gemini detected as FREE TIER -> Batch=%d, Delay=%dms", s.batchSize, s.minDelayMs)
			return { ok = true, tier = "free", summary = s.detectedTierSummary }
		elseif res.ok then
			s.detectedTier = "paid"
			if s.autoTuneQuota ~= false then
				s.batchSize = 45
				s.minDelayMs = 250
				s.maxCharsPerBatch = 8500
			end
			s.detectedTierSummary = M.FormatTierSummary(s)
			s.tierSignature = sig
			M.SaveSettings()
			M.Log("Gemini detected as PAID TIER -> Batch=%d, Delay=%dms", s.batchSize, s.minDelayMs)
			return { ok = true, tier = "paid", summary = s.detectedTierSummary }
		else
			local listRes = M.HttpRequest({
				url = endpoint .. "/models?pageSize=5&key=" .. apiKey,
				method = "GET",
				timeout = 15000,
			})
			if not listRes.ok and (listRes.status == 400 or listRes.status == 401 or listRes.status == 403) then
				s.detectedTier = "invalid"
				s.detectedTierSummary = M.FormatTierSummary(s)
				M.SaveSettings()
				return { ok = false, invalidKey = true, summary = s.detectedTierSummary }
			end
			s.detectedTier = "free"
			local bSize, delayMs, maxChars = tune_gemini_free_for_model(model)
			if s.autoTuneQuota ~= false then
				s.batchSize = bSize
				s.minDelayMs = delayMs
				s.maxCharsPerBatch = maxChars
			end
			s.detectedTierSummary = M.FormatTierSummary(s)
			s.tierSignature = sig
			M.SaveSettings()
			return { ok = true, tier = "free", summary = s.detectedTierSummary }
		end
	end

	-- 3. OpenRouter: endpoint dedicado /auth/key informa is_free_tier com precisão
	if prov == "openrouter" then
		local res = M.HttpRequest({
			url = endpoint .. "/auth/key",
			method = "GET",
			headers = { ["Authorization"] = "Bearer " .. apiKey },
			timeout = 15000,
		})
		if res.status == 401 or res.status == 403 then
			s.detectedTier = "invalid"
			s.detectedTierSummary = M.FormatTierSummary(s)
			M.SaveSettings()
			return { ok = false, invalidKey = true, summary = s.detectedTierSummary }
		end
		local parsed = M.JsonDecode(res.body)
		local isFree = (type(parsed) == "table" and type(parsed.data) == "table" and parsed.data.is_free_tier == true)
			or (string.lower(model):find(":free", 1, true) ~= nil)

		if isFree then
			s.detectedTier = "free"
			if s.autoTuneQuota ~= false then
				s.batchSize = 40
				s.minDelayMs = 3500
				s.maxCharsPerBatch = 7500
			end
		else
			s.detectedTier = "paid"
			if s.autoTuneQuota ~= false then
				s.batchSize = 45
				s.minDelayMs = 300
				s.maxCharsPerBatch = 8500
			end
		end
		s.detectedTierSummary = M.FormatTierSummary(s)
		s.tierSignature = sig
		M.SaveSettings()
		return { ok = true, tier = s.detectedTier, summary = s.detectedTierSummary }
	end

	-- 4. Groq / OpenAI / DeepSeek / Custom Cloud
	local modelsRes = M.HttpRequest({
		url = endpoint .. "/models",
		method = "GET",
		headers = apiKey ~= "" and { ["Authorization"] = "Bearer " .. apiKey } or {},
		timeout = 15000,
	})
	if modelsRes.status == 401 or modelsRes.status == 403 then
		s.detectedTier = "invalid"
		s.detectedTierSummary = M.FormatTierSummary(s)
		M.SaveSettings()
		return { ok = false, invalidKey = true, summary = s.detectedTierSummary }
	end

	if prov == "groq" then
		s.detectedTier = "free"
		if s.autoTuneQuota ~= false then
			s.batchSize = 22
			s.minDelayMs = 4500
			s.maxCharsPerBatch = 3200
		end
	else
		s.detectedTier = "paid"
		if s.autoTuneQuota ~= false then
			s.batchSize = 40
			s.minDelayMs = 350
			s.maxCharsPerBatch = 8000
		end
	end

	s.detectedTierSummary = M.FormatTierSummary(s)
	s.tierSignature = sig
	M.SaveSettings()
	return { ok = true, tier = s.detectedTier, summary = s.detectedTierSummary }
end

-- ============================================================================
-- Listagem Ao Vivo de Modelos Disponíveis na API
-- ============================================================================

local excluded_gemini_keywords = {
	"embedding", "imagen", "veo", "tts", "audio", "aqa", "bisheng",
	"robotics", "computer-use", "learnlm", "image-generation", "-image",
}

function M.FetchAvailableModels(settings)
	local s = settings or M.LoadSettings()
	local prov = string.lower(tostring(s.provider or "gemini"))
	local meta = M.GetProviderMeta(prov)
	local apiKey = M.GetActiveApiKey(s)
	local endpoint = get_endpoint(s)

	if meta.requiresKey and apiKey == "" then
		return meta.models, "Sem API Key configurada (exibindo lista padrão)"
	end

	local collected = {}
	local seen = {}

	if prov == "gemini" then
		local pageToken = nil
		for _ = 1, 5 do
			local url = endpoint .. "/models?pageSize=100&key=" .. apiKey
			if pageToken and pageToken ~= "" then
				url = url .. "&pageToken=" .. pageToken
			end
			local res = M.HttpRequest({ url = url, method = "GET", timeout = 20000 })
			if not res.ok then
				if #collected > 0 then break end
				return meta.models, "Falha ao listar modelos (" .. tostring(res.err) .. ")"
			end
			local parsed = M.JsonDecode(res.body)
			if type(parsed) ~= "table" or type(parsed.models) ~= "table" then
				break
			end
			for _, m in ipairs(parsed.models) do
				if type(m) == "table" and type(m.name) == "string" then
					local id = m.name:gsub("^models/", "")
					local low = string.lower(id)
					local supportsGen = false
					if type(m.supportedGenerationMethods) == "table" then
						for _, method in ipairs(m.supportedGenerationMethods) do
							if method == "generateContent" then
								supportsGen = true
								break
							end
						end
					end
					local excluded = false
					for _, kw in ipairs(excluded_gemini_keywords) do
						if low:find(kw, 1, true) then
							excluded = true
							break
						end
					end
					if supportsGen and not excluded and low:find("^gemini") and not seen[id] then
						seen[id] = true
						collected[#collected + 1] = id
					end
				end
			end
			pageToken = parsed.nextPageToken
			if not pageToken or pageToken == "" then
				break
			end
		end
	else
		local headers = {}
		if apiKey ~= "" then
			headers["Authorization"] = "Bearer " .. apiKey
		end
		local res = M.HttpRequest({ url = endpoint .. "/models", method = "GET", headers = headers, timeout = 20000 })
		if not res.ok then
			return meta.models, "Falha ao consultar /models (" .. tostring(res.err) .. ")"
		end
		local parsed = M.JsonDecode(res.body)
		local list = (type(parsed) == "table" and (parsed.data or parsed.models)) or nil
		if type(list) == "table" then
			for _, item in ipairs(list) do
				local id = type(item) == "table" and (item.id or item.name) or nil
				if type(id) == "string" and id ~= "" and not seen[id] then
					seen[id] = true
					collected[#collected + 1] = id
				end
			end
		end
	end

	if #collected == 0 then
		return meta.models, nil
	end

	-- Ordena priorizando modelos recomendados no topo
	local priority = {}
	for idx, pref in ipairs(meta.models) do
		priority[pref] = idx
	end
	table.sort(collected, function(a, b)
		local pa = priority[a] or 999
		local pb = priority[b] or 999
		if pa ~= pb then return pa < pb end
		return a < b
	end)

	return collected, nil
end

-- ============================================================================
-- Tradutor de Lotes com Pacer Anti-429, Retry Inteligente e Split Automático
-- ============================================================================

local function wait_for_rate_limit_pacer(settings)
	local minDelay = tonumber(settings.minDelayMs) or 0
	if minDelay <= 0 then
		local nowFn = rawget(_ENV, "RealTime")
		M.LastApiCallRealTime = nowFn and nowFn() or 0
		return
	end

	local nowFn = rawget(_ENV, "RealTime")
	local sleepFn = rawget(_ENV, "Sleep")
	if not nowFn or not sleepFn then return end

	local elapsed = nowFn() - (M.LastApiCallRealTime or 0)
	if M.LastApiCallRealTime > 0 and elapsed < minDelay then
		sleepFn(minDelay - elapsed)
	end
	M.LastApiCallRealTime = nowFn()
end

local function classify_429_error(bodyStr)
	local body = tostring(bodyStr or "")
	local low = string.lower(body)

	-- Detecta esgotamento de cota DIÁRIA ou falta de saldo (não adianta repetir em loop curto)
	local isDaily = low:find("perday", 1, true) ~= nil
		or low:find("per_day", 1, true) ~= nil
		or low:find("requests per day", 1, true) ~= nil
		or low:find("daily", 1, true) ~= nil
		or low:find("insufficient_quota", 1, true) ~= nil
		or low:find("exceeded your current quota, please check your plan", 1, true) ~= nil

	-- Extrai retryDelay sugerido pelo servidor (ex: "retryDelay": "28s" ou "Please retry in 21.4s")
	local retrySec = tonumber(body:match('"retryDelay"%s*:%s*"(%d+)'))
		or tonumber(body:match("retry in (%d+%.?%d*)s"))
		or tonumber(body:match("try again in (%d+%.?%d*)s"))

	return isDaily, retrySec
end

local function build_system_prompt(sourceLangMeta, targetLangMeta, modTitle)
	local srcName = sourceLangMeta and sourceLangMeta.promptName or "English"
	local dstName = targetLangMeta and targetLangMeta.promptName or "Portuguese (Brazil)"
	return table.concat({
		"You are an expert game localization translator for the tactical RPG 'Jagged Alliance 3' (mod: '" .. tostring(modTitle or "Mod") .. "').",
		"Translate every item in the JSON array from " .. srcName .. " into natural, idiomatic " .. dstName .. " fitting military/mercenary tactical RPG terminology.",
		"STRICT RULES:",
		"1. Keep EVERY placeholder token like ⟦T0⟧, ⟦T1⟧, ⟦T2⟧ EXACTLY intact in its proper grammatical position. NEVER translate, rename, space out, or delete any ⟦Tn⟧ token.",
		"2. Preserve line breaks (\\n), bullet symbols, +/- stat signs, weapon calibers (e.g. 5.56mm, 7.62x39, .50 BMG), and proper mercenary nicknames.",
		"3. Return ONLY a valid JSON object in the exact schema: {\"t\":[{\"i\":1,\"v\":\"translated text\"}, ...]} matching every input index \"i\". No markdown, no explanations.",
	}, "\n")
end

local function execute_single_ai_request(payloadArray, sysPrompt, settings)
	local prov = string.lower(tostring(settings.provider or "gemini"))
	local apiKey = M.GetActiveApiKey(settings)
	local model = M.GetActiveModel(settings)
	local endpoint = get_endpoint(settings)
	local userJson = M.JsonEncode(M.JsonArray(payloadArray))

	wait_for_rate_limit_pacer(settings)

	if prov == "gemini" then
		local url = endpoint .. "/models/" .. model .. ":generateContent?key=" .. apiKey
		local genCfg = {
			temperature = 0.15,
			responseMimeType = "application/json",
		}
		-- Desativa thinking extra apenas na família gemini-2.5-flash para resposta rápida e econômica
		if string.lower(model):find("^gemini%-2%.5%-flash") then
			genCfg.thinkingConfig = { thinkingBudget = 0 }
		end

		local reqBody = M.JsonEncode({
			systemInstruction = {
				parts = M.JsonArray({ { text = sysPrompt } }),
			},
			contents = M.JsonArray({
				{
					role = "user",
					parts = M.JsonArray({ { text = userJson } }),
				},
			}),
			generationConfig = genCfg,
		})

		local res = M.HttpRequest({
			url = url,
			method = "POST",
			headers = { ["Content-Type"] = "application/json" },
			body = reqBody,
			timeout = 95000,
		})
		if not res.ok then
			return nil, res
		end

		local parsed, jErr = M.JsonDecode(res.body)
		if type(parsed) ~= "table" then
			return nil, { ok = false, status = 200, body = res.body, err = "Resposta JSON invalida: " .. tostring(jErr) }
		end
		local cand = type(parsed.candidates) == "table" and parsed.candidates[1]
		local content = type(cand) == "table" and cand.content
		local parts = type(content) == "table" and content.parts
		if type(parts) == "table" then
			local texts = {}
			for _, p in ipairs(parts) do
				if type(p) == "table" and type(p.text) == "string" and not p.thought then
					texts[#texts + 1] = p.text
				end
			end
			return table.concat(texts, "\n"), res
		end
		return nil, { ok = false, status = 200, body = res.body, err = "Candidato vazio do Gemini" }
	else
		local url = endpoint .. "/chat/completions"
		local headers = {
			["Content-Type"] = "application/json",
		}
		if apiKey ~= "" then
			headers["Authorization"] = "Bearer " .. apiKey
		end
		if prov == "openrouter" then
			headers["HTTP-Referer"] = "https://github.com/JA3TradutorIA"
			headers["X-Title"] = "JA3 Tradutor IA In-Game Mod"
		end

		local bodyTbl = {
			model = model,
			temperature = 0.15,
			messages = M.JsonArray({
				{ role = "system", content = sysPrompt },
				{ role = "user", content = userJson },
			}),
		}
		if prov == "openai" or prov == "deepseek" or prov == "groq" then
			bodyTbl.response_format = { type = "json_object" }
		end

		local res = M.HttpRequest({
			url = url,
			method = "POST",
			headers = headers,
			body = M.JsonEncode(bodyTbl),
			timeout = 110000,
		})
		if not res.ok then
			return nil, res
		end

		local parsed, jErr = M.JsonDecode(res.body)
		if type(parsed) ~= "table" then
			return nil, { ok = false, status = 200, body = res.body, err = "JSON invalido: " .. tostring(jErr) }
		end
		local choice = type(parsed.choices) == "table" and parsed.choices[1]
		local msg = type(choice) == "table" and choice.message
		local text = type(msg) == "table" and msg.content
		if type(text) == "string" and text ~= "" then
			return text, res
		end
		return nil, { ok = false, status = 200, body = res.body, err = "Resposta vazia do provedor" }
	end
end

local function parse_ai_translation_payload(rawAiText, expectedCount)
	if type(rawAiText) ~= "string" or rawAiText == "" then
		return nil
	end

	local decoded = M.JsonDecode(rawAiText)
	if type(decoded) ~= "table" then
		local objSlice = M.ExtractFirstJsonBlock(rawAiText, "{", "}")
		if objSlice then
			decoded = M.JsonDecode(objSlice)
		end
		if type(decoded) ~= "table" then
			local arrSlice = M.ExtractFirstJsonBlock(rawAiText, "[", "]")
			if arrSlice then
				decoded = M.JsonDecode(arrSlice)
			end
		end
	end

	if type(decoded) ~= "table" then
		return nil
	end

	local arr = decoded.t or decoded.translations or decoded.items or decoded
	if type(arr) ~= "table" then
		return nil
	end

	local mapByIndex = {}
	local found = 0
	for k, entry in pairs(arr) do
		if type(entry) == "table" then
			local idx = tonumber(entry.i or entry.id or entry.index or k)
			local val = entry.v or entry.t or entry.text or entry.value or entry.translation
			if idx and type(val) == "string" and val ~= "" then
				mapByIndex[idx] = val
				found = found + 1
			end
		elseif type(k) == "number" and type(entry) == "string" and entry ~= "" then
			mapByIndex[k] = entry
			found = found + 1
		end
	end

	if found == 0 then
		return nil
	end
	-- Aceita o lote se pelo menos 70% dos itens vieram preenchidos (os faltantes serão reprocessados se necessário)
	if expectedCount > 2 and found < math.floor(expectedCount * 0.7) then
		return nil
	end
	return mapByIndex
end

-- Traduz uma lista de itens únicos { sourceText = "..." } -> retorna { ok, translations = { [srcText] = dstText }, ... }
function M.TranslateUniqueBatch(uniqueSources, sourceLangMeta, targetLangMeta, modTitle, settings, onWaitStatus, splitDepth)
	splitDepth = splitDepth or 0
	local s = settings or M.LoadSettings()
	local count = #uniqueSources
	if count == 0 then
		return { ok = true, translations = {} }
	end

	local prepared = {}
	local payload = {}
	for i = 1, count do
		local src = uniqueSources[i]
		local masked, tags = M.ProtectTags(src)
		prepared[i] = { source = src, masked = masked, tags = tags }
		payload[i] = { i = i, s = masked }
	end

	local sysPrompt = build_system_prompt(sourceLangMeta, targetLangMeta, modTitle)
	local sleepFn = rawget(_ENV, "Sleep")
	local lastErr = "Falha desconhecida"

	for attempt = 1, 4 do
		if M.CancelRequested then
			return { ok = false, cancelled = true, err = M.Tr("status_paused_user") }
		end

		local aiText, httpRes = execute_single_ai_request(payload, sysPrompt, s)
		if aiText then
			local indexMap = parse_ai_translation_payload(aiText, count)
			if indexMap then
				local out = {}
				local missing = {}
				for i = 1, count do
					local rawTranslated = indexMap[i]
					if type(rawTranslated) == "string" and M.Trim(rawTranslated) ~= "" then
						out[prepared[i].source] = M.RestoreTags(rawTranslated, prepared[i].tags)
					else
						missing[#missing + 1] = prepared[i].source
					end
				end

				-- Se algum item isolado faltou no JSON e ainda podemos completar, faz sub-chamada apenas dos faltantes
				if #missing > 0 and #missing < count and splitDepth < 2 then
					local subRes = M.TranslateUniqueBatch(missing, sourceLangMeta, targetLangMeta, modTitle, s, onWaitStatus, splitDepth + 1)
					if subRes.ok and type(subRes.translations) == "table" then
						for k, v in pairs(subRes.translations) do
							out[k] = v
						end
					end
				end

				return { ok = true, translations = out }
			else
				lastErr = "JSON da IA incompleto ou malformado"
				-- Se o lote for grande e o modelo truncou o JSON, divide ao meio automaticamente!
				if count >= 4 and splitDepth < 3 then
					local mid = math.floor(count / 2)
					local left, right = {}, {}
					for i = 1, mid do left[#left + 1] = uniqueSources[i] end
					for i = mid + 1, count do right[#right + 1] = uniqueSources[i] end

					M.Log("Dividindo lote de %d -> %d + %d para evitar truncamento JSON.", count, #left, #right)
					local r1 = M.TranslateUniqueBatch(left, sourceLangMeta, targetLangMeta, modTitle, s, onWaitStatus, splitDepth + 1)
					if not r1.ok then return r1 end
					local r2 = M.TranslateUniqueBatch(right, sourceLangMeta, targetLangMeta, modTitle, s, onWaitStatus, splitDepth + 1)
					if not r2.ok then return r2 end

					local merged = {}
					for k, v in pairs(r1.translations) do merged[k] = v end
					for k, v in pairs(r2.translations) do merged[k] = v end
					return { ok = true, translations = merged }
				end
			end
		elseif httpRes then
			if httpRes.status == 429 then
				local isDaily, retrySec = classify_429_error(httpRes.body)
				if isDaily then
					return {
						ok = false,
						dailyQuotaExhausted = true,
						err = M.Tr("err_429_daily"),
					}
				end

				-- Auto-ajusta o intervalo mínimo para não voltar a bater em 429 nos próximos lotes
				if s.autoTuneQuota ~= false then
					s.minDelayMs = math.min(20000, math.max((tonumber(s.minDelayMs) or 4000) + 1500, 5000))
					M.SaveSettings()
				end

				local waitSeconds = math.ceil(retrySec or (attempt * 15))
				if waitSeconds < 8 then waitSeconds = 8 end
				if waitSeconds > 65 then waitSeconds = 65 end

				for rem = waitSeconds, 1, -1 do
					if M.CancelRequested then
						return { ok = false, cancelled = true, err = M.Tr("status_paused_user") }
					end
					if onWaitStatus then
						onWaitStatus(M.Tr("wait_429_rpm_fmt", rem))
					end
					if sleepFn then sleepFn(1000) end
				end
				M.LastApiCallRealTime = 0
			elseif httpRes.status == 401 or httpRes.status == 403 then
				return {
					ok = false,
					invalidKey = true,
					err = M.Tr("err_invalid_key_http_fmt", tostring(httpRes.err)),
				}
			else
				lastErr = tostring(httpRes.err or "Network error")
				if sleepFn and attempt < 4 then
					if onWaitStatus then
						onWaitStatus(M.Tr("wait_retry_fmt", attempt + 1))
					end
					sleepFn(attempt * 2500)
				end
			end
		end
	end

	return { ok = false, err = lastErr }
end
