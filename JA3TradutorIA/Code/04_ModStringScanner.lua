-- ============================================================================
-- JA3 Tradutor IA - 04_ModStringScanner.lua
-- Scanner nativo de mods instalados/ativos (.hpk da Steam Workshop e pastas em
-- AppData/Mods) + Detector automático do idioma original de cada mod.
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

-- Decodifica literais de string Lua ("...", '...', [[...]], [=[...]=]) a partir de startPos
local simple_escapes = {
	[string.byte("a")]  = "\a",
	[string.byte("b")]  = "\b",
	[string.byte("f")]  = "\f",
	[string.byte("n")]  = "\n",
	[string.byte("r")]  = "\r",
	[string.byte("t")]  = "\t",
	[string.byte("v")]  = "\v",
	[string.byte("\\")] = "\\",
	[string.byte('"')]  = '"',
	[string.byte("'")]  = "'",
	[string.byte("\n")] = "\n",
}

local function parse_lua_string_at(src, pos)
	local len = #src
	if pos > len then return nil, pos end

	local ch = src:byte(pos)
	-- String entre aspas duplas ou simples
	if ch == 34 or ch == 39 then -- '"' ou "'"
		local quote = ch
		local i = pos + 1
		local chunks = {}
		local chunkStart = i
		while i <= len do
			local b = src:byte(i)
			if b == quote then
				if i > chunkStart then
					chunks[#chunks + 1] = src:sub(chunkStart, i - 1)
				end
				return table.concat(chunks), i + 1
			elseif b == 92 then -- '\\'
				if i > chunkStart then
					chunks[#chunks + 1] = src:sub(chunkStart, i - 1)
				end
				local nextB = src:byte(i + 1)
				if not nextB then return nil, i + 1 end
				if simple_escapes[nextB] then
					chunks[#chunks + 1] = simple_escapes[nextB]
					i = i + 2
				elseif nextB == 13 then -- \r\n
					chunks[#chunks + 1] = "\n"
					if src:byte(i + 2) == 10 then
						i = i + 3
					else
						i = i + 2
					end
				elseif nextB >= 48 and nextB <= 57 then -- \ddd decimal
					local decStr = src:match("^(%d%d?%d?)", i + 1)
					local decVal = tonumber(decStr)
					if decVal and decVal <= 255 then
						chunks[#chunks + 1] = string.char(decVal)
					end
					i = i + 1 + #decStr
				elseif nextB == 122 then -- \z pula espaços
					local _, wsEnd = src:find("^%s*", i + 2)
					i = (wsEnd or (i + 1)) + 1
				else
					chunks[#chunks + 1] = string.char(nextB)
					i = i + 2
				end
				chunkStart = i
			elseif b == 10 or b == 13 then
				-- String de linha única quebrada sem escape: inválida
				return nil, i + 1
			else
				i = i + 1
			end
		end
		return nil, len + 1
	end

	-- Long bracket string [[...]] ou [=[...]=]
	if ch == 91 then -- '['
		local eqs, bodyStart = src:match("^%[(=*)%[()", pos)
		if eqs then
			local closePat = "]" .. eqs .. "]"
			local closeStart, closeEnd = src:find(closePat, bodyStart, true)
			if not closeStart then
				return nil, len + 1
			end
			local content = src:sub(bodyStart, closeStart - 1)
			-- Pela especificação Lua, remove uma quebra de linha imediatamente após [[
			if content:sub(1, 2) == "\r\n" then
				content = content:sub(3)
			elseif content:sub(1, 1) == "\n" or content:sub(1, 1) == "\r" then
				content = content:sub(2)
			end
			return content, closeEnd + 1
		end
	end

	return nil, pos + 1
end

local function skip_ws_and_comments(src, pos)
	local len = #src
	while pos <= len do
		local _, wsEnd = src:find("^%s+", pos)
		if wsEnd then
			pos = wsEnd + 1
		end
		if src:sub(pos, pos + 1) == "--" then
			local eqs, cBody = src:match("^%-%-%[(=*)%[()", pos)
			if eqs then
				local _, cEnd = src:find("]" .. eqs .. "]", cBody, true)
				if not cEnd then return len + 1 end
				pos = cEnd + 1
			else
				local nl = src:find("\n", pos + 2, true)
				if not nl then return len + 1 end
				pos = nl + 1
			end
		else
			break
		end
	end
	return pos
end

-- Extrai todos os pares T(id, "texto") / T{id, "texto"} de um código-fonte Lua
function M.ScanLuaSourceForTs(src, outEntries)
	if type(src) ~= "string" or #src < 6 then return end
	local pos = 1
	local len = #src

	while pos <= len do
		local tStart, tEnd = src:find("T%s*[%(%{]", pos)
		if not tStart then break end

		-- Garante que 'T' não é final de outro identificador (ex: IsT(, GetT(, Untranslated()
		local prevByte = tStart > 1 and src:byte(tStart - 1) or 32
		local isWordChar = (prevByte >= 48 and prevByte <= 57)
			or (prevByte >= 65 and prevByte <= 90)
			or (prevByte >= 97 and prevByte <= 122)
			or prevByte == 95

		if isWordChar then
			pos = tStart + 1
		else
			local cur = skip_ws_and_comments(src, tEnd + 1)
			local idStr, afterComma = src:match("^(%d+)%s*,()", cur)
			if idStr and afterComma then
				cur = skip_ws_and_comments(src, afterComma)
				local strVal, afterStr = parse_lua_string_at(src, cur)
				if strVal and M.IsTranslatableText(strVal) then
					local numId = tonumber(idStr)
					if numId and not outEntries[idStr] then
						outEntries[idStr] = {
							key = idStr,
							numId = numId,
							sourceText = strVal,
						}
					end
				end
				pos = afterStr or (tEnd + 1)
			else
				pos = tEnd + 1
			end
		end
	end
end

-- Extrai opções PlaceObj('ModItemOption...', { ... }) de items.lua caso o mod não esteja carregado na RAM
function M.ScanItemsLuaForModOptions(modId, src, outEntries)
	if type(src) ~= "string" or not src:find("ModItemOption", 1, true) then return end
	local pos = 1
	while true do
		local pStart, pEnd = src:find("PlaceObj%s*%(%s*['\"]ModItemOption[%w_]*['\"]%s*,%s*%{", pos)
		if not pStart then break end
		-- Captura o bloco da tabela do PlaceObj até o fechamento correspondente
		local depth = 1
		local i = pEnd + 1
		local len = #src
		while i <= len and depth > 0 do
			local b = src:byte(i)
			if b == 34 or b == 39 or b == 91 then
				local _, nextI = parse_lua_string_at(src, i)
				i = (nextI and nextI > i) and nextI or (i + 1)
			elseif b == 123 then -- '{'
				depth = depth + 1
				i = i + 1
			elseif b == 125 then -- '}'
				depth = depth - 1
				i = i + 1
			else
				i = i + 1
			end
		end

		local block = src:sub(pEnd, i - 1)
		local optName = block:match("['\"]name['\"]%s*,%s*['\"]([^'\"]+)['\"]")
		if optName and optName ~= "" then
			for _, field in ipairs({ "DisplayName", "Help" }) do
				local _, fEnd = block:find("['\"]" .. field .. "['\"]%s*,%s*")
				if fEnd then
					local val = parse_lua_string_at(block, fEnd + 1)
					if val and M.IsTranslatableText(val) then
						local key = "opt|" .. modId .. "|" .. optName .. "|" .. field
						if not outEntries[key] then
							outEntries[key] = {
								key = key,
								numId = nil,
								sourceText = val,
							}
						end
					end
				end
			end

			-- Escaneia itens em ChoiceList (para ModItemOptionChoice)
			local cStart, cEnd = block:find("['\"]ChoiceList['\"]%s*,%s*%{")
			if cEnd then
				local cDepth = 1
				local cPos = cEnd + 1
				local bLen = #block
				while cPos <= bLen and cDepth > 0 do
					local b = block:byte(cPos)
					if b == 34 or b == 39 or b == 91 then
						local strVal, nextPos = parse_lua_string_at(block, cPos)
						if strVal and M.IsTranslatableText(strVal) then
							local key = "opt|" .. modId .. "|" .. optName .. "|Choice|" .. strVal
							if not outEntries[key] then
								outEntries[key] = {
									key = key,
									numId = nil,
									sourceText = strVal,
								}
							end
						end
						cPos = (nextPos and nextPos > cPos) and nextPos or (cPos + 1)
					elseif b == 123 then
						cDepth = cDepth + 1
						cPos = cPos + 1
					elseif b == 125 then
						cDepth = cDepth - 1
						cPos = cPos + 1
					else
						cPos = cPos + 1
					end
				end
			end
		end

		pos = i
	end
end

-- Percorre objetos já carregados em mod.items na memória
local function walk_loaded_mod_items(modDef, outEntries)
	if type(modDef) ~= "table" then return end

	local isT = rawget(_ENV, "IsT")
	local tGetId = rawget(_ENV, "TGetID")
	local isKindOf = rawget(_ENV, "IsKindOf")
	local visited = {}

	local function register_mod_option_item(item)
		if type(item) ~= "table" then return end
		local optName = rawget(item, "name") or item.name
		if type(optName) ~= "string" or optName == "" then return end

		for _, field in ipairs({ "DisplayName", "Help" }) do
			local orig = rawget(item, "__ja3tr_orig_" .. field)
			local val = (type(orig) == "string" and orig) or rawget(item, field) or item[field]
			if type(val) == "string" and M.IsTranslatableText(val) then
				local key = "opt|" .. modDef.id .. "|" .. optName .. "|" .. field
				if not outEntries[key] then
					outEntries[key] = {
						key = key,
						numId = nil,
						sourceText = val,
					}
				end
			end
		end

		local choices = rawget(item, "ChoiceList") or item.ChoiceList
		if type(choices) == "table" then
			for _, choiceStr in ipairs(choices) do
				if type(choiceStr) == "string" and M.IsTranslatableText(choiceStr) then
					local key = "opt|" .. modDef.id .. "|" .. optName .. "|Choice|" .. choiceStr
					if not outEntries[key] then
						outEntries[key] = {
							key = key,
							numId = nil,
							sourceText = choiceStr,
						}
					end
				end
			end
		end
	end

	-- 1. Se o mod possuir GetOptionItems, usa diretamente a API nativa do JA3
	if type(modDef.GetOptionItems) == "function" then
		local ok, optItems = pcall(modDef.GetOptionItems, modDef)
		if ok and type(optItems) == "table" then
			for _, opt in ipairs(optItems) do
				register_mod_option_item(opt)
			end
		end
	end

	-- 2. Varredura recursiva nos itens carregados
	if type(modDef.items) ~= "table" then return end

	local function visit(tbl, depth)
		if depth > 14 or type(tbl) ~= "table" or visited[tbl] then return end
		visited[tbl] = true

		if isT and isT(tbl) then
			local numId = tGetId and tGetId(tbl)
			local txt = nil
			if type(tbl[1]) == "number" and type(tbl[2]) == "string" then
				txt = tbl[2]
			elseif type(tbl[1]) == "string" then
				txt = tbl[1]
			end
			if type(numId) == "number" and type(txt) == "string" and M.IsTranslatableText(txt) then
				local key = tostring(numId)
				if not outEntries[key] then
					outEntries[key] = {
						key = key,
						numId = numId,
						sourceText = txt,
					}
				end
			end
			return
		end

		local cls = rawget(tbl, "class") or tbl.class
		local isOpt = (type(cls) == "string" and cls:find("^ModItemOption"))
			or (isKindOf and isKindOf(tbl, "ModItemOption"))
			or (rawget(tbl, "DisplayName") ~= nil and rawget(tbl, "name") ~= nil)

		if isOpt then
			register_mod_option_item(tbl)
		end

		for k, v in pairs(tbl) do
			if k ~= "mod" and k ~= "__index" and k ~= "env" and k ~= "Container" and type(v) == "table" then
				visit(v, depth + 1)
			end
		end
	end

	for _, item in ipairs(modDef.items) do
		visit(item, 0)
	end
end

-- ============================================================================
-- Detecção Automática de Idioma Original do Mod
-- ============================================================================

local lang_stopwords = {
	["en"]    = { "the", "and", "with", "from", "your", "this", "that", "for", "when", "have", "damage", "attack", "weapon", "merc" },
	["pt-BR"] = { "para", "com", "uma", "não", "mais", "como", "dos", "das", "pelo", "esta", "seu", "sua", "dano", "ataque" },
	["es"]    = { "para", "con", "una", "por", "más", "como", "los", "las", "del", "pero", "este", "esta", "daño" },
	["fr"]    = { "pour", "avec", "dans", "les", "des", "une", "pas", "plus", "sur", "est", "sont", "cette", "arme" },
	["de"]    = { "der", "die", "das", "und", "mit", "für", "nicht", "eine", "einem", "auf", "ist", "wird", "schaden" },
	["it"]    = { "per", "con", "una", "che", "non", "più", "della", "delle", "degli", "sono", "questo", "danno" },
	["pl"]    = { "nie", "dla", "oraz", "jest", "czy", "jak", "przy", "tylko", "przez", "jego", "obrażenia" },
	["tr"]    = { "için", "bir", "ile", "olan", "daha", "veya", "gibi", "kadar", "olarak", "hasar" },
}

function M.DetectLanguageFromEntries(entriesMap)
	local samples = {}
	for _, entry in pairs(entriesMap) do
		if type(entry.sourceText) == "string" then
			samples[#samples + 1] = entry.sourceText
			if #samples >= 80 then break end
		end
	end

	if #samples == 0 then
		return M.LangByCode["en"]
	end

	local blob = table.concat(samples, " \n ")
	-- Remove tags para não enviesar o detector com palavras em inglês (<color>, <image>)
	blob = blob:gsub("<[/%a_][^>\r\n]*>", " ")

	-- 1. Detecção de scripts não-latinos (Cirílico, Japonês, Coreano, Chinês)
	local cyrillic = 0
	local hiraganaKatakana = 0
	local hangul = 0
	local cjk = 0

	local i = 1
	local n = #blob
	while i <= n do
		local b1 = blob:byte(i)
		if b1 >= 208 and b1 <= 211 and i + 1 <= n then
			cyrillic = cyrillic + 1
			i = i + 2
		elseif b1 == 227 and i + 2 <= n then
			local b2 = blob:byte(i + 1)
			if b2 >= 129 and b2 <= 131 then
				hiraganaKatakana = hiraganaKatakana + 1
			end
			i = i + 3
		elseif b1 >= 234 and b1 <= 237 and i + 2 <= n then
			hangul = hangul + 1
			i = i + 3
		elseif b1 >= 228 and b1 <= 233 and i + 2 <= n then
			cjk = cjk + 1
			i = i + 3
		else
			i = i + 1
		end
	end

	if hiraganaKatakana >= 4 then
		return M.LangByCode["ja"]
	end
	if hangul >= 4 then
		return M.LangByCode["ko"]
	end
	if cjk >= 6 then
		return M.LangByCode["zh-CN"]
	end
	if cyrillic >= 10 then
		if blob:find("і", 1, true) or blob:find("ї", 1, true) or blob:find("є", 1, true) then
			return M.LangByCode["uk"]
		end
		return M.LangByCode["ru"]
	end

	-- 2. Detecção de idiomas latinos por stopwords
	local lower = " " .. string.lower(blob):gsub("[%p%d]+", " ") .. " "
	local bestCode = "en"
	local bestScore = 0

	for code, words in pairs(lang_stopwords) do
		local score = 0
		for _, w in ipairs(words) do
			local _, cnt = lower:gsub("%s" .. w .. "%s", " ")
			score = score + cnt
		end
		if score > bestScore then
			bestScore = score
			bestCode = code
		end
	end

	-- Desempate por diacríticos específicos caso score seja baixo
	if bestScore <= 2 then
		if lower:find("ção", 1, true) or lower:find("ões", 1, true) or lower:find("não", 1, true) then
			bestCode = "pt-BR"
		elseif lower:find("ción", 1, true) or lower:find("ñ", 1, true) then
			bestCode = "es"
		elseif lower:find("ß", 1, true) or lower:find("ä", 1, true) or lower:find("ü", 1, true) then
			bestCode = "de"
		end
	end

	return M.LangByCode[bestCode] or M.LangByCode["en"]
end

function M.IsCompanionOrSelfMod(modDef)
	if type(modDef) ~= "table" then return true end
	local myId = rawget(_ENV, "CurrentModId") or "JA3TradutorIA"
	local id = tostring(modDef.id or "")
	if id == "" or id == myId or id == "JA3TradutorIA" then
		return true
	end
	if id:find("_Trad_", 1, true) then
		return true
	end
	local title = tostring(modDef.title or "")
	if title:find("[TRADUÇÃO IA]", 1, true) or title:find("[TRADUCAO IA]", 1, true) then
		return true
	end
	local path = tostring(modDef.path or "")
	if path:find("_Traducao_", 1, true) then
		return true
	end
	return false
end

-- Escaneia um único ModDef e retorna { id, title, sourceLang, entries, totalCount, nativeTargetIds }
function M.ScanSingleMod(modDef, targetLangMeta, settings)
	if M.IsCompanionOrSelfMod(modDef) then
		return nil
	end

	local s = settings or M.LoadSettings()
	targetLangMeta = targetLangMeta or M.ResolveLanguage(s.targetLanguage)

	local entries = {}
	local nativeTargetIds = {}
	local sleepFn = rawget(_ENV, "Sleep")

	-- 1. Lê tabelas de localização (.csv) caso o mod possua
	local loadCsv = rawget(_ENV, "LoadCSV")
	if type(loadCsv) == "function" and type(modDef.content_path) == "string" and M.AsyncListFiles then
		-- Verifica primeiro mod.loctables para identificar traduções oficiais do próprio autor do mod
		if type(modDef.loctables) == "table" then
			for _, lt in ipairs(modDef.loctables) do
				if type(lt) == "table" and type(lt.filename) == "string" and lt.filename ~= "" then
					local csvPath = lt.filename
					if not csvPath:find("^Mod/") and not csvPath:find(":") then
						csvPath = modDef.content_path .. csvPath
					end
					local rows = {}
					loadCsv(csvPath, rows, nil, true)
					-- Ignora dumps acidentais da Game.csv inteira do jogo base (>15.000 linhas)
					if #rows > 0 and #rows < 15000 and tostring(rows[1][1] or "") ~= "887406599613" then
						local isTargetLoc = (lt.language == targetLangMeta.ja3Value) or (lt.language == "Any" and #modDef.loctables > 1)
						for _, r in ipairs(rows) do
							local idStr = M.Trim(tostring(r[1] or ""))
							local numId = tonumber(idStr)
							local txt = tostring((r[3] and r[3] ~= "" and r[3]) or (r[2] and r[2] ~= "" and r[2]) or (r[5] or ""))
							if numId and txt ~= "" then
								if isTargetLoc then
									nativeTargetIds[idStr] = true
								elseif M.IsTranslatableText(txt) and not entries[idStr] then
									entries[idStr] = { key = idStr, numId = numId, sourceText = txt }
								end
							end
						end
					end
				end
			end
		end
	end

	-- 2. Inspeciona objetos carregados em modDef.items (mods ativos)
	walk_loaded_mod_items(modDef, entries)

	-- 3. Escaneia todos os arquivos .lua montados em modDef.content_path (funciona para .hpk e pastas!)
	if type(modDef.content_path) == "string" and modDef.content_path ~= "" and M.AsyncListFiles and M.AsyncFileToString then
		local err, luaFiles = M.AsyncListFiles(modDef.content_path, "*.lua", "recursive")
		if not err and type(luaFiles) == "table" then
			for idx, filePath in ipairs(luaFiles) do
				local lowName = string.lower(tostring(filePath))
				if not lowName:find("metadata%.lua$") then
					local fErr, src = M.AsyncFileToString(filePath)
					if not fErr and type(src) == "string" and #src > 0 then
						M.ScanLuaSourceForTs(src, entries)
						if lowName:find("items%.lua$") then
							M.ScanItemsLuaForModOptions(modDef.id, src, entries)
						end
					end
				end
				-- Cede 1 tick a cada 12 arquivos para manter 60 FPS lisos no jogo
				if sleepFn and (idx % 12 == 0) then
					sleepFn(0)
				end
			end
		end
	end

	-- Remove IDs que o próprio autor do mod já traduziu oficialmente para o idioma destino
	for idStr in pairs(nativeTargetIds) do
		entries[idStr] = nil
	end

	-- 4. Opcionalmente inclui a descrição do mod no menu MODS se ativado nas configurações
	if s.translateModDescriptions ~= false and type(modDef.description) == "string" and modDef.description ~= "" then
		if M.IsTranslatableText(modDef.description) then
			local descKey = "desc|" .. modDef.id
			entries[descKey] = { key = descKey, numId = nil, sourceText = modDef.description, isDescription = true }
		end
	end

	local orderedList = {}
	for _, item in pairs(entries) do
		orderedList[#orderedList + 1] = item
	end
	table.sort(orderedList, function(a, b) return a.key < b.key end)

	local detectedLang = M.DetectLanguageFromEntries(entries)

	local loadedList = rawget(_ENV, "ModsLoaded")
	local isActiveMod = false
	if type(loadedList) == "table" then
		for _, m in ipairs(loadedList) do
			if type(m) == "table" and m.id == modDef.id then
				isActiveMod = true
				break
			end
		end
	end

	return {
		id = modDef.id,
		title = tostring(modDef.title or modDef.id),
		source = tostring(modDef.source or "appdata"),
		packed = not not modDef.packed,
		isActive = isActiveMod,
		sourceLang = detectedLang,
		entries = orderedList,
		totalCount = #orderedList,
	}
end

-- Escaneia todos os mods conforme o escopo configurado ("active" vs "all")
function M.ScanAllTargetMods(settings)
	local s = settings or M.LoadSettings()
	local targetLangMeta = M.ResolveLanguage(s.targetLanguage)
	local scanAll = M.IsAllModsScope(s.scanScope)

	local sourceList
	if scanAll then
		sourceList = rawget(_ENV, "ModsList") or rawget(_ENV, "ModsLoaded") or {}
	else
		sourceList = rawget(_ENV, "ModsLoaded") or {}
	end

	local results = {}
	local seenIds = {}
	local sleepFn = rawget(_ENV, "Sleep")

	for _, modDef in ipairs(sourceList) do
		if type(modDef) == "table" and modDef.id and not seenIds[modDef.id] then
			seenIds[modDef.id] = true
			if not M.IsCompanionOrSelfMod(modDef) then
				-- Caso seja um mod inativo mas o escopo seja "Todos os Mods Instalados", garante que esteja montado
				if not modDef.mounted and type(modDef.MountContent) == "function" then
					pcall(modDef.MountContent, modDef)
				end
				local report = M.ScanSingleMod(modDef, targetLangMeta, s)
				if report and report.totalCount > 0 then
					results[#results + 1] = report
				end
				if sleepFn then
					sleepFn(0)
				end
			end
		end
	end

	return results, targetLangMeta
end
