-- ============================================================================
-- JA3 Tradutor IA - 02_TagProtector.lua
-- Proteção e restauração 100% segura de tags Haemimont/JA3 (<color>, <image>,
-- <u(...)>, <style>, placeholders %s/%d/{0}) durante a tradução por IA.
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

-- Protege todas as tags especiais do motor JA3 substituindo por tokens ⟦T0⟧, ⟦T1⟧...
function M.ProtectTags(text)
	if type(text) ~= "string" or text == "" then
		return text or "", nil
	end

	local tags = {}
	local function push_tag(match)
		local idx = #tags
		tags[idx + 1] = match
		return "⟦T" .. tostring(idx) .. "⟧"
	end

	-- 1. Tags XML/Haemimont (<color ...>, </color>, <image ...>, <u(...)>, <newline>, <UnitName>, etc.)
	local masked = text:gsub("<[/%a_][^>\r\n]*>", push_tag)

	-- 2. BBCode simples ([b], [/b], [i], [/i]) caso usado em descrições de mods
	masked = masked:gsub("%[/?[biBI]%]", push_tag)

	-- 3. Placeholders posicionais {0}, {1}
	masked = masked:gsub("{%d+}", push_tag)

	-- 4. Especificadores printf (%s, %d, %.1f, %02d, %%)
	masked = masked:gsub("%%[-+0 #]*%d*%.?%d*[sdifuxXegGp%%]", push_tag)

	if #tags == 0 then
		return text, nil
	end
	return masked, tags
end

-- Restaura os tokens ⟦Tn⟧ de volta para as tags originais exatas do JA3
function M.RestoreTags(translated, tags)
	if type(translated) ~= "string" or translated == "" then
		return translated or ""
	end

	-- Mesmo sem tags originais, removemos tags <fn()> inventadas pela IA para nunca quebrar TTranslate
	if not tags or #tags == 0 then
		return (translated:gsub("<[/%a_][^>\r\n]*>", ""))
	end

	local s = translated

	-- Normaliza variações comuns que modelos de IA às vezes produzem nos tokens
	s = s:gsub("⟦%s*[tT](%d+)%s*⟧", "⟦T%1⟧")
	s = s:gsub("%[%[%s*[tT](%d+)%s*%]%]", "⟦T%1⟧")
	s = s:gsub("<%s*[tT](%d+)%s*>", "⟦T%1⟧")
	s = s:gsub("【%s*[tT](%d+)%s*】", "⟦T%1⟧")
	s = s:gsub("%[%s*T(%d+)%s*%]", "⟦T%1⟧")

	-- Remove qualquer tag <...> espúria inventada pela IA antes de reinserir as originais
	s = s:gsub("<[/%a_][^>\r\n]*>", "")

	local used = {}
	s = s:gsub("⟦T(%d+)⟧", function(numStr)
		local idx = (tonumber(numStr) or -1) + 1
		local orig = tags[idx]
		if orig then
			used[idx] = true
			return orig
		end
		return ""
	end)

	-- Garante que tags de fechamento (</color>, </style>, </em>, </h>, </scale>) não fiquem órfãs
	-- caso o modelo tenha mantido a abertura mas esquecido o fechamento.
	for i = 1, #tags do
		if not used[i] then
			local t = tags[i]
			if t:sub(1, 2) == "</" or t:sub(1, 2) == "[/" then
				s = s .. t
			end
		end
	end

	return s
end

-- Remove pontuação/símbolos UTF-8 comuns que não são letras traduzíveis
local non_letter_utf8 = {
	["•"] = "", ["–"] = "", ["—"] = "", ["…"] = "", ["“"] = "", ["”"] = "",
	["‘"] = "", ["’"] = "", ["«"] = "", ["»"] = "", ["™"] = "", ["®"] = "",
	["©"] = "", ["°"] = "", ["±"] = "", ["×"] = "", ["÷"] = "", ["→"] = "",
	["←"] = "", ["↑"] = "", ["↓"] = "", ["▪"] = "", ["▸"] = "", ["★"] = "",
}

-- Verifica se uma string realmente contém texto humano traduzível
function M.IsTranslatableText(str)
	if type(str) ~= "string" then return false end
	local trimmed = M.Trim(str)
	if #trimmed < 2 then return false end

	-- Ignora caminhos de arquivos/assets e identificadores técnicos com underscore sem espaço
	if not trimmed:find("%s") then
		if trimmed:find("^UI/") or trimmed:find("^Mod/") or trimmed:find("^Assets/") or trimmed:find("^Sounds/") then
			return false
		end
		if trimmed:find("_", 1, true) and trimmed:match("^[%w_%.%-/]+$") then
			return false
		end
		if trimmed:match("^https?://") then
			return false
		end
	end

	-- Remove tags JA3 e placeholders para checar se sobra alguma letra real
	local stripped = trimmed
		:gsub("<[/%a_][^>\r\n]*>", " ")
		:gsub("%[/?[biBI]%]", " ")
		:gsub("{%d+}", " ")
		:gsub("%%[-+0 #]*%d*%.?%d*[sdifuxXegGp%%]", " ")

	for sym, repl in pairs(non_letter_utf8) do
		stripped = stripped:gsub(sym, repl)
	end

	-- Tem letra ASCII?
	if stripped:find("%a") then
		return true
	end

	-- Tem caractere UTF-8 multibyte (Cirílico, CJK, Acentos, etc.)?
	if stripped:find("[\194-\244][\128-\191]") then
		return true
	end

	return false
end
