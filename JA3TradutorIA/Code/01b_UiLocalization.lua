-- ============================================================================
-- JA3 Tradutor IA - 01b_UiLocalization.lua
-- Sistema de localização nativa da interface do próprio Mod: detecta o idioma
-- atual do Jagged Alliance 3 (GetLanguage()) e mantém 100% dos menus, botões,
-- opções de mod, HUD e diálogos no mesmo idioma do jogo em tempo real.
-- ============================================================================

local M = rawget(_ENV, "JA3TradutorIA")
if not M then
	M = {}
	rawset(_ENV, "JA3TradutorIA", M)
end

-- Mapeamento do valor interno de GetLanguage() do JA3 para nossa tabela de UI
local JA3_TO_UI_LANG = {
	Brazilian  = "pt",
	Portuguese = "pt",
	English    = "en",
	Spanish    = "es",
	Latam      = "es",
	French     = "fr",
	German     = "de",
	Russian    = "ru",
	Polish     = "pl",
	Indonesian = "id",
	Schinese   = "zh-CN",
	Tchinese   = "zh-TW",
	Italian    = "it",
	Japanese   = "ja",
	Koreana    = "ko",
	Turkish    = "tr",
	Ukrainian  = "uk",
}

local UI_STRINGS = {
	-- ========================================================================
	-- ENGLISH (Default / Fallback + GetLanguage() == "English")
	-- ========================================================================
	["en"] = {
		menu_button = "AI TRANSLATOR",
		hud_brand = "JA3 AI TRANSLATOR",
		mod_title = "JA3 AI Translator (Background Auto-Translator)",
		mod_desc = "Automatically detects installed/active Jagged Alliance 3 mods, identifies each mod's source language, and translates all texts in the background directly inside the game using AI (Google Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama, or LM Studio) without any external executable.\n\n• Automatically saves and restores all translations across sessions.\n• Automatically detects Free vs Paid API keys and tunes batch size & delay to prevent 429 quota errors.\n• In-game shortcut: press Ctrl+Shift+T (or click 'AI TRANSLATOR' in Mod Manager / Pause Menu).",
		mod_changes = "100% native in-game background translator, multi-language UI synced with game language, and automatic Free/Paid quota calibration.",

		opt_auto_name = "Auto-Translate in Background",
		opt_auto_help = "When enabled, automatically detects and translates pending mod texts in the background as soon as the mod is enabled or the game starts.",
		opt_lang_name = "Target Translation Language",
		opt_lang_help = "Choose which language mods will be translated into inside the game.",
		opt_choice_auto_lang = "Auto (Game Language)",
		opt_prov_name = "AI Provider",
		opt_prov_help = "AI engine used for translation. Press Ctrl+Shift+T (or click 'AI TRANSLATOR') to paste your API Key.",
		opt_model_name = "AI Model",
		opt_model_help = "Select 'Auto (Saved in Panel)' to use the model chosen in Ctrl+Shift+T, or pick a preset model directly.",
		opt_choice_auto_model = "Auto (Saved in Panel)",
		opt_scope_name = "Mods to Translate",
		opt_scope_help = "'Active Mods Only' translates mods enabled in your current profile. 'All Installed Mods' also pre-translates inactive mods.",
		opt_choice_scope_active = "Active Mods Only",
		opt_choice_scope_all = "All Installed Mods",
		opt_quota_name = "Auto-Tune Quota (Free vs Paid Key)",
		opt_quota_help = "Automatically detects whether your API key is Free Tier or Paid Tier and calibrates batch size and request delay to avoid HTTP 429 errors.",
		opt_desc_name = "Translate Mod Descriptions in MODS Menu",
		opt_desc_help = "Translates the titles and descriptions of mods in the in-game Mod Manager into your language.",
		opt_hud_name = "Show On-Screen Progress Indicator",
		opt_hud_help = "Displays a compact non-intrusive bar in the top-right corner while translating in the background and hides automatically when done.",

		badge_free = "[FREE TIER]",
		badge_paid = "[PAID TIER]",
		badge_local = "[LOCAL AI]",
		badge_invalid = "[INVALID KEY]",
		badge_auto = "[AUTO]",

		tier_free_fmt = "Free Tier • Batch: %d • Delay: %.1fs",
		tier_paid_fmt = "Paid Tier • High Speed • Batch: %d • Delay: %.2fs",
		tier_local_fmt = "Local Offline AI • No Quota Limit (Batch: %d)",
		tier_invalid = "Invalid or rejected API Key",
		tier_missing_key = "API Key not configured (Press Ctrl+Shift+T)",
		tier_unknown = "Waiting for automatic quota detection",
		provider_no_key_tag = " [No API Key]",

		btn_ok = "OK",
		btn_yes = "Yes",
		btn_cancel = "Cancel",
		key_not_set = "Not configured",
		key_set_short = "Configured (••••)",
		key_set_masked_fmt = "Configured (%s••••%s)",
		state_on = "Enabled",
		state_hidden = "Hidden",
		state_active = "Active",
		state_inactive = "Inactive",
		state_idle = "Ready",
		state_translating = "Translating...",

		status_init = "Initializing...",
		status_paused = "Paused",
		status_paused_user = "Paused by user",
		status_restarting = "Restarting scan...",
		status_switching_lang = "Switching target language...",
		status_clearing_cache = "Clearing cache...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T to resume)",
		status_auto_off_fmt = "Auto-translate disabled (%d saved texts applied)",
		status_scanning = "Scanning installed mods...",
		hud_scanning_detail = "Checking mod texts and original languages...",
		status_no_mods = "No other translatable mods active right now",
		hud_no_mods_title = "No Pending Mods",
		hud_no_mods_detail = "Enable mods in Mod Manager and they will be translated automatically.",
		status_done_fmt = "100%% Translated (%d active texts in %s)",
		hud_all_done_title = "Mods 100% Translated!",
		hud_all_done_detail_fmt = "%d texts applied in %s.",
		status_need_key_fmt = "%d pending texts • Set API Key (Ctrl+Shift+T)",
		hud_need_key_title = "API Key Required",
		hud_need_key_detail_fmt = "%d new texts found! Press Ctrl+Shift+T to paste your API Key.",
		status_calibrating = "Checking API quota (Free vs Paid)...",
		hud_calibrating_title = "Calibrating API Quota...",
		hud_calibrating_detail_fmt = "%d new texts to translate into %s...",
		status_invalid_key = "Invalid API Key • Press Ctrl+Shift+T to fix",
		hud_invalid_key_title = "Invalid API Key",
		hud_invalid_key_detail = "Key rejected by provider. Press Ctrl+Shift+T to update.",
		status_batch_fmt = "%s: batch %d/%d (%d%%)",
		hud_batch_detail_fmt = "%s -> %s • Batch %d/%d (%d/%d texts)",
		hud_saved_live_fmt = "Saved live! %d/%d texts translated into %s",
		hud_paused_quota_title = "Translation Paused",
		hud_finished_title = "Translation Complete!",
		hud_finished_detail_fmt = "All active mods are translated into %s (%d saved texts).",

		err_429_daily = "Daily free quota reached on this model. Press Ctrl+Shift+T to switch model (e.g. gemini-2.5-flash <-> gemini-2.5-flash-lite).",
		wait_429_rpm_fmt = "Per-minute limit (429) • Auto-resuming in %ds...",
		wait_retry_fmt = "Reconnecting to AI (attempt %d/4)...",
		err_invalid_key_http_fmt = "Invalid or unauthorized API Key (%s). Check Ctrl+Shift+T.",

		panel_title_fmt = "JA3 AI TRANSLATOR v%s — Background Panel (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUSE] Pause Background Translation (%s)",
		menu_1_start = "1. [START] Translate / Scan Mods in Background Now",
		menu_2_status_fmt = "2. [STATUS] %s | Cache: %d texts",
		menu_3_key_fmt = "3. [API KEY] Paste or Change API Key (%s)",
		menu_4_prov_fmt = "4. [PROVIDER] AI Engine: %s",
		menu_5_model_fmt = "5. [MODEL] AI Model: %s (Fetch from API)",
		menu_6_lang_fmt = "6. [LANGUAGE] Target Language: %s -> %s",
		menu_7_quota_fmt = "7. [QUOTA] %s",
		menu_8_mods = "8. [MODS] View Detected Mods, Source Language & Progress",
		menu_9_hud_fmt = "9. [HUD] Corner Progress Banner: %s",
		menu_desc_fmt = "10. [MOD DESCRIPTIONS] Translate Descriptions in MODS Menu: %s",
		menu_11_retranslate = "11. [RE-TRANSLATE] Rescan / Clear Language Cache",
		menu_0_close = "0. Close Panel (Translation continues in background)",

		dlg_status_title = "JA3 AI Translator Status",
		dlg_status_body_fmt = "Current State: %s\nProvider: %s\nActive Model: %s\nAPI Key: %s\nQuota Profile: %s\nCurrent Calibration: Batch = %d texts | Min delay = %d ms\nEffective Target Language: %s (%s)\nSaved on Disk: %d unique texts (%d in-game IDs)",

		dlg_key_title_fmt = "API Key — %s",
		dlg_key_placeholder = "Paste your API Key here with Ctrl+V",
		dlg_key_desc_fmt = "Press Ctrl+V to paste your API key (%s). It is stored locally in AppData/JA3TradutorIA.",
		hud_validating_key_title = "Validating API Key...",
		hud_validating_key_detail = "Automatically detecting Free vs Paid tier...",
		dlg_key_saved_title = "API Key Saved & Calibrated",
		dlg_key_saved_body_fmt = "Provider: %s\nKey: %s\nResult: %s\n\n%s",
		dlg_key_saved_ok = "Background auto-translation will now start!",
		dlg_key_saved_check = "Please verify that your API key was pasted correctly.",

		dlg_prov_title = "Choose AI Provider",
		dlg_endpoint_title = "OpenAI-Compatible Endpoint",
		dlg_endpoint_desc = "Enter the base URL (e.g. http://localhost:8000/v1):",

		hud_fetching_models_title = "Fetching models...",
		hud_fetching_models_detail_fmt = "Querying available models from %s...",
		dlg_model_title_fmt = "Select or Type AI Model (%s)",

		dlg_lang_title = "Target Translation Language",

		hud_testing_api_title = "Testing API...",
		hud_testing_api_detail = "Checking Free vs Paid tier...",
		dlg_quota_title = "API Quota Diagnostics",
		dlg_quota_body_fmt = "Provider: %s\nModel: %s\nResult: %s\nCalibrated Batch: %d texts per request\nAnti-429 Delay: %d ms between requests",

		dlg_mods_title = "Detected Mods & Progress",
		dlg_mods_empty_fmt = "No other translatable mods were found in the current scope (%s).\n\nEnable Steam Workshop or AppData/Mods mods and they will be detected automatically!",
		dlg_mods_header_fmt = "Target Language: %s (%s)\nSaved Global Cache: %d unique texts | %d applied IDs\n------------------------------------------------------------",
		dlg_mods_native_lang = "Already in target language",
		dlg_mods_item_fmt = "%d. %s [%s]\n   Detected language: %s -> %s",

		hud_enabled_title = "HUD Enabled",
		hud_enabled_detail = "The compact progress bar will appear during translations.",

		dlg_retranslate_title = "Rescan / Clear Language Cache",
		dlg_retranslate_confirm_fmt = "Do you want to clear ALL saved cache for '%s' and re-translate from scratch?\n\n(Choose 'Cancel' to simply rescan for new texts while keeping existing translations.)",
	},

	-- ========================================================================
	-- PORTUGUÊS (GetLanguage() == "Brazilian" | "Portuguese")
	-- ========================================================================
	["pt"] = {
		menu_button = "TRADUTOR IA",
		hud_brand = "JA3 TRADUTOR IA",
		mod_title = "JA3 Tradutor IA (Auto-Tradutor em Background)",
		mod_desc = "Detecta automaticamente os mods instalados/ativos do Jagged Alliance 3, identifica o idioma original de cada mod e traduz todos os textos em segundo plano diretamente dentro do jogo usando IA (Google Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama ou LM Studio), sem depender de nenhum executável externo.\n\n• Salva e restaura todas as traduções automaticamente entre sessões.\n• Detecta automaticamente se sua chave API é Gratuita ou Paga e calibra lote e intervalo contra erro 429.\n• Atalho no jogo: pressione Ctrl+Shift+T (ou clique em 'TRADUTOR IA' no Gerenciador de Mods / Pausa).",
		mod_changes = "Mod 100% nativo em background, interface sincronizada automaticamente com o idioma do jogo e calibração de cota Free/Paga.",

		opt_auto_name = "Traduzir Automaticamente em Background",
		opt_auto_help = "Quando ativado, detecta e traduz automaticamente em segundo plano todos os textos pendentes dos mods assim que o mod é ativado ou o jogo inicia.",
		opt_lang_name = "Idioma Destino da Tradução",
		opt_lang_help = "Escolha para qual idioma os mods serão traduzidos dentro do jogo.",
		opt_choice_auto_lang = "Auto (Idioma do Jogo)",
		opt_prov_name = "Provedor de IA",
		opt_prov_help = "Motor de IA usado na tradução. Pressione Ctrl+Shift+T (ou clique em 'TRADUTOR IA') para colar sua API Key.",
		opt_model_name = "Modelo de IA",
		opt_model_help = "Escolha 'Auto (Salvo no Painel)' para manter o modelo escolhido em Ctrl+Shift+T, ou selecione diretamente um modelo.",
		opt_choice_auto_model = "Auto (Salvo no Painel)",
		opt_scope_name = "Quais Mods Traduzir",
		opt_scope_help = "'Apenas Mods Ativos' traduz somente os mods habilitados no perfil atual. 'Todos os Mods Instalados' pré-traduz também os inativos.",
		opt_choice_scope_active = "Apenas Mods Ativos",
		opt_choice_scope_all = "Todos os Mods Instalados",
		opt_quota_name = "Auto-Ajuste de Cota (Chave Gratuita vs Paga)",
		opt_quota_help = "Detecta automaticamente se sua chave API é Gratuita (Free Tier) ou Paga e calibra lote e intervalo para não estourar a cota (Erro 429).",
		opt_desc_name = "Traduzir Descrições dos Mods no Menu MODS",
		opt_desc_help = "Traduz os títulos e descrições dos mods exibidos no menu de Mods do jogo para o seu idioma.",
		opt_hud_name = "Mostrar Indicador de Progresso na Tela",
		opt_hud_help = "Exibe uma barra discreta no canto superior direito enquanto traduz em segundo plano e oculta automaticamente ao concluir.",

		badge_free = "[COTA GRATUITA]",
		badge_paid = "[COTA PAGA]",
		badge_local = "[IA LOCAL]",
		badge_invalid = "[CHAVE INVÁLIDA]",
		badge_auto = "[AUTO]",

		tier_free_fmt = "Chave Gratuita (Free Tier) • Lote: %d • Intervalo: %.1fs",
		tier_paid_fmt = "Chave Paga (Paid Tier) • Alta Velocidade • Lote: %d • Intervalo: %.2fs",
		tier_local_fmt = "IA Local Offline • Sem limite de cota (Lote: %d)",
		tier_invalid = "API Key inválida ou recusada pelo provedor",
		tier_missing_key = "API Key não configurada (Pressione Ctrl+Shift+T)",
		tier_unknown = "Aguardando detecção automática de cota",
		provider_no_key_tag = " [Sem API Key]",

		btn_ok = "OK",
		btn_yes = "Sim",
		btn_cancel = "Cancelar",
		key_not_set = "Não configurada",
		key_set_short = "Configurada (••••)",
		key_set_masked_fmt = "Configurada (%s••••%s)",
		state_on = "Ativado",
		state_hidden = "Oculto",
		state_active = "Ativo",
		state_inactive = "Inativo",
		state_idle = "Pronto",
		state_translating = "Traduzindo...",

		status_init = "Inicializando...",
		status_paused = "Pausado",
		status_paused_user = "Pausado pelo usuário",
		status_restarting = "Reiniciando verificação...",
		status_switching_lang = "Trocando idioma destino...",
		status_clearing_cache = "Limpando cache...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T para retomar)",
		status_auto_off_fmt = "Auto-tradução desativada (%d textos salvos aplicados)",
		status_scanning = "Escaneando mods instalados...",
		hud_scanning_detail = "Verificando textos e idiomas originais...",
		status_no_mods = "Nenhum outro mod traduzível ativo no momento",
		hud_no_mods_title = "Nenhum mod pendente",
		hud_no_mods_detail = "Ative mods no Gerenciador e eles serão traduzidos automaticamente.",
		status_done_fmt = "100%% Traduzido (%d textos ativos em %s)",
		hud_all_done_title = "Mods 100% Traduzidos!",
		hud_all_done_detail_fmt = "%d textos aplicados em %s.",
		status_need_key_fmt = "%d textos pendentes • Configure sua API Key (Ctrl+Shift+T)",
		hud_need_key_title = "API Key Necessária",
		hud_need_key_detail_fmt = "%d textos novos encontrados! Pressione Ctrl+Shift+T para colar sua API Key.",
		status_calibrating = "Verificando cota da API (Gratuita vs Paga)...",
		hud_calibrating_title = "Calibrando Cota da API...",
		hud_calibrating_detail_fmt = "%d textos novos para traduzir para %s...",
		status_invalid_key = "API Key inválida • Pressione Ctrl+Shift+T para corrigir",
		hud_invalid_key_title = "API Key Inválida",
		hud_invalid_key_detail = "Sua chave foi recusada pelo provedor. Pressione Ctrl+Shift+T para atualizar.",
		status_batch_fmt = "%s: lote %d/%d (%d%%)",
		hud_batch_detail_fmt = "%s -> %s • Lote %d/%d (%d/%d textos)",
		hud_saved_live_fmt = "Salvo ao vivo! %d/%d textos traduzidos em %s",
		hud_paused_quota_title = "Tradução Pausada",
		hud_finished_title = "Tradução Concluída!",
		hud_finished_detail_fmt = "Todos os mods ativos estão traduzidos em %s (%d textos salvos).",

		err_429_daily = "Cota diária gratuita atingida neste modelo. Pressione Ctrl+Shift+T para trocar de modelo (ex: gemini-2.5-flash <-> gemini-2.5-flash-lite).",
		wait_429_rpm_fmt = "Limite por minuto (429) • Retomando automaticamente em %ds...",
		wait_retry_fmt = "Reconectando à IA (tentativa %d/4)...",
		err_invalid_key_http_fmt = "API Key inválida ou sem permissão (%s). Verifique em Ctrl+Shift+T.",

		panel_title_fmt = "JA3 TRADUTOR IA v%s — Painel em Background (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUSAR] Pausar Tradução em Background (%s)",
		menu_1_start = "1. [INICIAR] Traduzir / Verificar Mods em Background Agora",
		menu_2_status_fmt = "2. [STATUS] %s | Cache: %d textos",
		menu_3_key_fmt = "3. [API KEY] Colar ou Alterar Chave API (%s)",
		menu_4_prov_fmt = "4. [PROVEDOR] Motor de IA: %s",
		menu_5_model_fmt = "5. [MODELO] Modelo de IA: %s (Listar da API)",
		menu_6_lang_fmt = "6. [IDIOMA] Idioma Destino: %s -> %s",
		menu_7_quota_fmt = "7. [COTA IA] %s",
		menu_8_mods = "8. [MODS] Ver Mods Detectados, Idioma Original e Progresso",
		menu_9_hud_fmt = "9. [HUD] Indicador no Canto da Tela: %s",
		menu_desc_fmt = "10. [DESCRIÇÕES] Traduzir Descrições no Menu MODS: %s",
		menu_11_retranslate = "11. [RE-TRADUZIR] Re-verificar / Limpar Cache do Idioma",
		menu_0_close = "0. Fechar Painel (A tradução continua rodando em segundo plano)",

		dlg_status_title = "Status do JA3 Tradutor IA",
		dlg_status_body_fmt = "Estado Atual: %s\nProvedor: %s\nModelo Ativo: %s\nChave API: %s\nPerfil de Cota: %s\nCalibração Atual: Lote = %d textos | Intervalo mínimo = %d ms\nIdioma Destino Efetivo: %s (%s)\nSalvo em Disco: %d textos únicos (%d IDs no jogo)",

		dlg_key_title_fmt = "API Key — %s",
		dlg_key_placeholder = "Cole sua API Key aqui com Ctrl+V",
		dlg_key_desc_fmt = "Pressione Ctrl+V para colar sua chave de API (%s). Ela ficará salva localmente em AppData/JA3TradutorIA.",
		hud_validating_key_title = "Validando API Key...",
		hud_validating_key_detail = "Detectando automaticamente se a chave é Gratuita ou Paga...",
		dlg_key_saved_title = "API Key Salva e Calibrada",
		dlg_key_saved_body_fmt = "Provedor: %s\nChave: %s\nResultado: %s\n\n%s",
		dlg_key_saved_ok = "A tradução automática em segundo plano será iniciada!",
		dlg_key_saved_check = "Verifique se a chave foi colada corretamente.",

		dlg_prov_title = "Escolha o Provedor de IA",
		dlg_endpoint_title = "Endpoint OpenAI-Compatible",
		dlg_endpoint_desc = "Informe a URL base (ex: http://localhost:8000/v1):",

		hud_fetching_models_title = "Consultando modelos...",
		hud_fetching_models_detail_fmt = "Buscando lista de modelos disponíveis em %s...",
		dlg_model_title_fmt = "Escolha ou Digite o Modelo de IA (%s)",

		dlg_lang_title = "Idioma Destino da Tradução",

		hud_testing_api_title = "Testando API...",
		hud_testing_api_detail = "Verificando cota Gratuita vs Paga...",
		dlg_quota_title = "Diagnóstico de Cota da API",
		dlg_quota_body_fmt = "Provedor: %s\nModelo: %s\nDiagnóstico: %s\nLote Calibrado: %d textos por requisição\nIntervalo Anti-429: %d ms entre requisições",

		dlg_mods_title = "Mods Detectados e Progresso",
		dlg_mods_empty_fmt = "Nenhum outro mod traduzível foi encontrado no escopo atual (%s).\n\nAtive mods da Steam Workshop ou em AppData/Mods e eles serão detectados automaticamente!",
		dlg_mods_header_fmt = "Idioma Destino: %s (%s)\nCache Global Salvo: %d textos únicos | %d IDs aplicados\n------------------------------------------------------------",
		dlg_mods_native_lang = "Já está no idioma destino",
		dlg_mods_item_fmt = "%d. %s [%s]\n   Idioma detectado: %s -> %s",

		hud_enabled_title = "HUD Ativado",
		hud_enabled_detail = "O indicador discreto será exibido durante as traduções.",

		dlg_retranslate_title = "Re-verificar / Limpar Cache do Idioma",
		dlg_retranslate_confirm_fmt = "Deseja limpar TODO o cache salvo de '%s' e traduzir do zero pela IA?\n\n(Escolha 'Cancelar' se quiser apenas re-escanear novos textos mantendo tudo que já foi traduzido.)",
	},

	-- ========================================================================
	-- ESPAÑOL (GetLanguage() == "Spanish" | "Latam")
	-- ========================================================================
	["es"] = {
		menu_button = "TRADUCTOR IA",
		hud_brand = "JA3 TRADUCTOR IA",
		mod_title = "JA3 Traductor IA (Auto-Traductor en Segundo Plano)",
		mod_desc = "Detecta automáticamente los mods instalados/activos de Jagged Alliance 3, identifica el idioma original de cada mod y traduce todos los textos en segundo plano dentro del juego usando IA (Google Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama o LM Studio), sin ejecutables externos.\n\n• Guarda y restaura todas las traducciones automáticamente.\n• Detecta claves API Gratuitas vs de Pago para evitar errores 429.\n• Atajo en el juego: pulsa Ctrl+Shift+T (o haz clic en 'TRADUCTOR IA').",
		mod_changes = "Traductor nativo en segundo plano con interfaz sincronizada con el idioma del juego.",
		opt_auto_name = "Traducir Automáticamente en Segundo Plano",
		opt_auto_help = "Detecta y traduce automáticamente en segundo plano los textos pendientes de tus mods.",
		opt_lang_name = "Idioma de Destino",
		opt_lang_help = "Elige a qué idioma se traducirán los mods dentro del juego.",
		opt_choice_auto_lang = "Auto (Idioma del Juego)",
		opt_prov_name = "Proveedor de IA",
		opt_prov_help = "Motor de IA usado para traducir. Pulsa Ctrl+Shift+T para pegar tu API Key.",
		opt_model_name = "Modelo de IA",
		opt_model_help = "Elige 'Auto (Guardado en Panel)' o selecciona directamente un modelo.",
		opt_choice_auto_model = "Auto (Guardado en Panel)",
		opt_scope_name = "Mods a Traducir",
		opt_scope_help = "'Solo Mods Activos' traduce los mods habilitados. 'Todos los Mods Instalados' incluye los inactivos.",
		opt_choice_scope_active = "Solo Mods Activos",
		opt_choice_scope_all = "Todos los Mods Instalados",
		opt_quota_name = "Auto-Ajuste de Cuota (Gratis vs Pago)",
		opt_quota_help = "Detecta si tu clave API es Gratuita o de Pago y ajusta lote e intervalo contra errores 429.",
		opt_desc_name = "Traducir Descripciones de Mods en Menú MODS",
		opt_desc_help = "Traduce los títulos y descripciones de mods en el Administrador de Mods del juego a tu idioma.",
		opt_hud_name = "Mostrar Indicador de Progreso en Pantalla",
		opt_hud_help = "Muestra una barra discreta arriba a la derecha mientras traduce en segundo plano.",
		badge_free = "[CUOTA GRATIS]",
		badge_paid = "[CUOTA PAGA]",
		badge_local = "[IA LOCAL]",
		badge_invalid = "[CLAVE INVÁLIDA]",
		badge_auto = "[AUTO]",
		tier_free_fmt = "Clave Gratuita • Lote: %d • Intervalo: %.1fs",
		tier_paid_fmt = "Clave de Pago • Alta Velocidad • Lote: %d • Intervalo: %.2fs",
		tier_local_fmt = "IA Local sin Conexión • Sin límite (Lote: %d)",
		tier_invalid = "Clave API inválida o rechazada",
		tier_missing_key = "Clave API no configurada (Pulsa Ctrl+Shift+T)",
		tier_unknown = "Esperando detección automática de cuota",
		provider_no_key_tag = " [Sin API Key]",
		btn_ok = "OK", btn_yes = "Sí", btn_cancel = "Cancelar",
		key_not_set = "No configurada", key_set_short = "Configurada (••••)", key_set_masked_fmt = "Configurada (%s••••%s)",
		state_on = "Activado", state_hidden = "Oculto", state_active = "Activo", state_inactive = "Inactivo", state_idle = "Listo", state_translating = "Traduciendo...",
		status_init = "Inicializando...", status_paused = "En pausa", status_paused_user = "Pausado por el usuario",
		status_restarting = "Reiniciando escaneo...", status_switching_lang = "Cambiando idioma...", status_clearing_cache = "Limpiando caché...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T para reanudar)",
		status_auto_off_fmt = "Auto-traducción desactivada (%d textos aplicados)",
		status_scanning = "Escaneando mods instalados...", hud_scanning_detail = "Verificando textos e idiomas originales...",
		status_no_mods = "No hay otros mods traducibles activos", hud_no_mods_title = "Sin mods pendientes", hud_no_mods_detail = "Activa mods en el Gestor y se traducirán automáticamente.",
		status_done_fmt = "100%% Traducido (%d textos activos en %s)", hud_all_done_title = "¡Mods 100% Traducidos!", hud_all_done_detail_fmt = "%d textos aplicados en %s.",
		status_need_key_fmt = "%d textos pendientes • Configura tu API Key (Ctrl+Shift+T)", hud_need_key_title = "API Key Necesaria", hud_need_key_detail_fmt = "¡%d textos nuevos! Pulsa Ctrl+Shift+T para pegar tu API Key.",
		status_calibrating = "Verificando cuota de API (Gratis vs Pago)...", hud_calibrating_title = "Calibrando Cuota API...", hud_calibrating_detail_fmt = "%d textos nuevos para traducir a %s...",
		status_invalid_key = "API Key inválida • Pulsa Ctrl+Shift+T", hud_invalid_key_title = "API Key Inválida", hud_invalid_key_detail = "Clave rechazada por el proveedor. Pulsa Ctrl+Shift+T.",
		status_batch_fmt = "%s: lote %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Lote %d/%d (%d/%d textos)",
		hud_saved_live_fmt = "¡Guardado en vivo! %d/%d textos traducidos a %s",
		hud_paused_quota_title = "Traducción en Pausa", hud_finished_title = "¡Traducción Completada!", hud_finished_detail_fmt = "Todos los mods activos traducidos a %s (%d textos).",
		err_429_daily = "Cuota diaria alcanzada en este modelo. Pulsa Ctrl+Shift+T para cambiar de modelo.",
		wait_429_rpm_fmt = "Límite por minuto (429) • Reanudando en %ds...", wait_retry_fmt = "Reconectando a la IA (intento %d/4)...",
		err_invalid_key_http_fmt = "Clave API inválida o sin permiso (%s). Revisa Ctrl+Shift+T.",
		panel_title_fmt = "JA3 TRADUCTOR IA v%s — Panel en Segundo Plano (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUSAR] Pausar Traducción en Segundo Plano (%s)",
		menu_1_start = "1. [INICIAR] Traducir / Verificar Mods Ahora",
		menu_2_status_fmt = "2. [ESTADO] %s | Caché: %d textos",
		menu_3_key_fmt = "3. [API KEY] Pegar o Cambiar Clave API (%s)",
		menu_4_prov_fmt = "4. [PROVEEDOR] Motor de IA: %s",
		menu_5_model_fmt = "5. [MODELO] Modelo de IA: %s (Consultar API)",
		menu_6_lang_fmt = "6. [IDIOMA] Idioma Destino: %s -> %s",
		menu_7_quota_fmt = "7. [CUOTA IA] %s",
		menu_8_mods = "8. [MODS] Ver Mods Detectados, Idioma Original y Progreso",
		menu_9_hud_fmt = "9. [HUD] Indicador en Pantalla: %s",
		menu_desc_fmt = "10. [DESCRIPCIONES] Traducir Descripciones en Menú MODS: %s",
		menu_11_retranslate = "11. [RE-TRADUCIR] Re-escanear / Limpiar Caché del Idioma",
		menu_0_close = "0. Cerrar Panel (La traducción sigue en segundo plano)",
		dlg_status_title = "Estado de JA3 Traductor IA",
		dlg_status_body_fmt = "Estado: %s\nProveedor: %s\nModelo: %s\nClave API: %s\nCuota: %s\nCalibración: Lote = %d textos | Intervalo = %d ms\nIdioma Destino: %s (%s)\nGuardado en Disco: %d textos únicos (%d IDs)",
		dlg_key_title_fmt = "API Key — %s", dlg_key_placeholder = "Pega tu API Key aquí con Ctrl+V", dlg_key_desc_fmt = "Pulsa Ctrl+V para pegar tu clave (%s). Se guardará en AppData/JA3TradutorIA.",
		hud_validating_key_title = "Validando API Key...", hud_validating_key_detail = "Detectando cuota Gratuita vs Pago...",
		dlg_key_saved_title = "API Key Guardada y Calibrada", dlg_key_saved_body_fmt = "Proveedor: %s\nClave: %s\nResultado: %s\n\n%s",
		dlg_key_saved_ok = "¡La traducción automática comenzará ahora!", dlg_key_saved_check = "Verifica que la clave se haya pegado correctamente.",
		dlg_prov_title = "Elegir Proveedor de IA", dlg_endpoint_title = "Endpoint Compatible con OpenAI", dlg_endpoint_desc = "Introduce la URL base (ej: http://localhost:8000/v1):",
		hud_fetching_models_title = "Consultando modelos...", hud_fetching_models_detail_fmt = "Buscando modelos disponibles en %s...", dlg_model_title_fmt = "Elige o Escribe el Modelo de IA (%s)",
		dlg_lang_title = "Idioma de Destino",
		hud_testing_api_title = "Probando API...", hud_testing_api_detail = "Verificando cuota Gratuita vs Pago...",
		dlg_quota_title = "Diagnóstico de Cuota API", dlg_quota_body_fmt = "Proveedor: %s\nModelo: %s\nResultado: %s\nLote Calibrado: %d textos\nIntervalo Anti-429: %d ms",
		dlg_mods_title = "Mods Detectados y Progreso",
		dlg_mods_empty_fmt = "No se encontraron otros mods traducibles (%s).",
		dlg_mods_header_fmt = "Idioma Destino: %s (%s)\nCaché Global: %d textos únicos | %d IDs aplicados\n------------------------------------------------------------",
		dlg_mods_native_lang = "Ya está en el idioma destino", dlg_mods_item_fmt = "%d. %s [%s]\n   Idioma detectado: %s -> %s",
		hud_enabled_title = "HUD Activado", hud_enabled_detail = "El indicador se mostrará durante las traducciones.",
		dlg_retranslate_title = "Re-escanear / Limpiar Caché", dlg_retranslate_confirm_fmt = "¿Deseas borrar TODA la caché guardada de '%s' y retraducir desde cero?\n\n(Elige 'Cancelar' para solo buscar textos nuevos manteniendo lo ya traducido.)",
	},

	-- ========================================================================
	-- FRANÇAIS (GetLanguage() == "French")
	-- ========================================================================
	["fr"] = {
		menu_button = "TRADUCTEUR IA",
		hud_brand = "JA3 TRADUCTEUR IA",
		mod_title = "JA3 Traducteur IA (Auto-Traducteur en Arrière-Plan)",
		mod_desc = "Détecte automatiquement les mods installés/actifs de Jagged Alliance 3, identifie leur langue d'origine et traduit tous les textes en arrière-plan directement dans le jeu via l'IA (Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio) sans exécutable externe.\n\n• Sauvegarde et restauration automatiques.\n• Détection automatique des clés API Gratuites vs Payantes (anti-429).\n• Raccourci en jeu : Ctrl+Shift+T (ou bouton 'TRADUCTEUR IA').",
		mod_changes = "Traducteur natif en arrière-plan avec interface synchronisée sur la langue du jeu.",
		opt_auto_name = "Traduire Automatiquement en Arrière-Plan",
		opt_auto_help = "Traduit automatiquement en arrière-plan tous les textes en attente dès l'activation.",
		opt_lang_name = "Langue Cible",
		opt_lang_help = "Choisissez la langue dans laquelle traduire les mods.",
		opt_choice_auto_lang = "Auto (Langue du Jeu)",
		opt_prov_name = "Fournisseur d'IA",
		opt_prov_help = "Moteur d'IA utilisé. Appuyez sur Ctrl+Shift+T pour coller votre clé API.",
		opt_model_name = "Modèle d'IA",
		opt_model_help = "Choisissez 'Auto (Enregistré dans le Panneau)' ou sélectionnez un modèle.",
		opt_choice_auto_model = "Auto (Enregistré dans le Panneau)",
		opt_scope_name = "Mods à Traduire",
		opt_scope_help = "'Mods Actifs Uniquement' ou 'Tous les Mods Installés'.",
		opt_choice_scope_active = "Mods Actifs Uniquement",
		opt_choice_scope_all = "Tous les Mods Installés",
		opt_quota_name = "Calibrage Auto du Quota (Gratuit vs Payant)",
		opt_quota_help = "Détecte si la clé API est Gratuite ou Payante et ajuste les lots pour éviter l'erreur 429.",
		opt_desc_name = "Traduire les Descriptions des Mods dans le Menu MODS",
		opt_desc_help = "Traduit les titres et descriptions des mods dans le Gestionnaire de Mods du jeu dans votre langue.",
		opt_hud_name = "Afficher l'Indicateur de Progression à l'Écran",
		opt_hud_help = "Affiche une barre discrète en haut à droite pendant la traduction.",
		badge_free = "[QUOTA GRATUIT]", badge_paid = "[QUOTA PAYANT]", badge_local = "[IA LOCALE]", badge_invalid = "[CLÉ INVALIDE]", badge_auto = "[AUTO]",
		tier_free_fmt = "Clé Gratuite • Lot : %d • Délai : %.1fs",
		tier_paid_fmt = "Clé Payante • Haute Vitesse • Lot : %d • Délai : %.2fs",
		tier_local_fmt = "IA Locale Hors-Ligne • Sans limite (Lot : %d)",
		tier_invalid = "Clé API invalide ou refusée",
		tier_missing_key = "Clé API non configurée (Ctrl+Shift+T)",
		tier_unknown = "En attente de détection du quota",
		provider_no_key_tag = " [Sans Clé API]",
		btn_ok = "OK", btn_yes = "Oui", btn_cancel = "Annuler",
		key_not_set = "Non configurée", key_set_short = "Configurée (••••)", key_set_masked_fmt = "Configurée (%s••••%s)",
		state_on = "Activé", state_hidden = "Masqué", state_active = "Actif", state_inactive = "Inactif", state_idle = "Prêt", state_translating = "Traduction...",
		status_init = "Initialisation...", status_paused = "En pause", status_paused_user = "Mis en pause par l'utilisateur",
		status_restarting = "Redémarrage de l'analyse...", status_switching_lang = "Changement de langue...", status_clearing_cache = "Nettoyage du cache...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T pour reprendre)",
		status_auto_off_fmt = "Auto-traduction désactivée (%d textes appliqués)",
		status_scanning = "Analyse des mods installés...", hud_scanning_detail = "Vérification des textes et langues d'origine...",
		status_no_mods = "Aucun autre mod traduisible actif", hud_no_mods_title = "Aucun mod en attente", hud_no_mods_detail = "Activez des mods dans le Gestionnaire pour les traduire automatiquement.",
		status_done_fmt = "100%% Traduit (%d textes actifs en %s)", hud_all_done_title = "Mods 100% Traduits !", hud_all_done_detail_fmt = "%d textes appliqués en %s.",
		status_need_key_fmt = "%d textes en attente • Clé API requise (Ctrl+Shift+T)", hud_need_key_title = "Clé API Requise", hud_need_key_detail_fmt = "%d nouveaux textes ! Appuyez sur Ctrl+Shift+T pour coller votre clé API.",
		status_calibrating = "Vérification du quota API...", hud_calibrating_title = "Calibrage du Quota API...", hud_calibrating_detail_fmt = "%d nouveaux textes à traduire en %s...",
		status_invalid_key = "Clé API invalide • Appuyez sur Ctrl+Shift+T", hud_invalid_key_title = "Clé API Invalide", hud_invalid_key_detail = "Clé refusée. Appuyez sur Ctrl+Shift+T pour la corriger.",
		status_batch_fmt = "%s : lot %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Lot %d/%d (%d/%d textes)",
		hud_saved_live_fmt = "Sauvegardé en direct ! %d/%d textes traduits en %s",
		hud_paused_quota_title = "Traduction en Pause", hud_finished_title = "Traduction Terminée !", hud_finished_detail_fmt = "Tous les mods actifs sont traduits en %s (%d textes).",
		err_429_daily = "Quota quotidien atteint sur ce modèle. Appuyez sur Ctrl+Shift+T pour changer de modèle.",
		wait_429_rpm_fmt = "Limite par minute (429) • Reprise dans %ds...", wait_retry_fmt = "Reconnexion à l'IA (tentative %d/4)...",
		err_invalid_key_http_fmt = "Clé API invalide (%s). Vérifiez via Ctrl+Shift+T.",
		panel_title_fmt = "JA3 TRADUCTEUR IA v%s — Panneau en Arrière-Plan (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUSE] Mettre en Pause la Traduction (%s)",
		menu_1_start = "1. [DÉMARRER] Traduire / Analyser les Mods Maintenant",
		menu_2_status_fmt = "2. [STATUT] %s | Cache : %d textes",
		menu_3_key_fmt = "3. [CLÉ API] Coller ou Modifier la Clé API (%s)",
		menu_4_prov_fmt = "4. [FOURNISSEUR] Moteur d'IA : %s",
		menu_5_model_fmt = "5. [MODÈLE] Modèle d'IA : %s (Lister via API)",
		menu_6_lang_fmt = "6. [LANGUE] Langue Cible : %s -> %s",
		menu_7_quota_fmt = "7. [QUOTA IA] %s",
		menu_8_mods = "8. [MODS] Voir les Mods Détectés, Langues et Progression",
		menu_9_hud_fmt = "9. [HUD] Indicateur à l'Écran : %s",
		menu_desc_fmt = "10. [DESCRIPTIONS] Traduire les Descriptions dans le Menu MODS : %s",
		menu_11_retranslate = "11. [RE-TRADUIRE] Réanalyser / Vider le Cache de la Langue",
		menu_0_close = "0. Fermer le Panneau (La traduction continue en arrière-plan)",
		dlg_status_title = "Statut de JA3 Traducteur IA",
		dlg_status_body_fmt = "État : %s\nFournisseur : %s\nModèle : %s\nClé API : %s\nQuota : %s\nCalibrage : Lot = %d textes | Délai = %d ms\nLangue Cible : %s (%s)\nSauvegardé : %d textes uniques (%d IDs)",
		dlg_key_title_fmt = "Clé API — %s", dlg_key_placeholder = "Collez votre clé API ici avec Ctrl+V", dlg_key_desc_fmt = "Appuyez sur Ctrl+V pour coller votre clé (%s).",
		hud_validating_key_title = "Validation de la clé API...", hud_validating_key_detail = "Détection du quota Gratuit vs Payant...",
		dlg_key_saved_title = "Clé API Enregistrée", dlg_key_saved_body_fmt = "Fournisseur : %s\nClé : %s\nRésultat : %s\n\n%s",
		dlg_key_saved_ok = "La traduction automatique démarre !", dlg_key_saved_check = "Vérifiez que la clé a été collée correctement.",
		dlg_prov_title = "Choisir le Fournisseur d'IA", dlg_endpoint_title = "Endpoint Compatible OpenAI", dlg_endpoint_desc = "Entrez l'URL de base (ex: http://localhost:8000/v1) :",
		hud_fetching_models_title = "Récupération des modèles...", hud_fetching_models_detail_fmt = "Consultation des modèles sur %s...", dlg_model_title_fmt = "Choisir ou Saisir le Modèle (%s)",
		dlg_lang_title = "Langue Cible de Traduction",
		hud_testing_api_title = "Test de l'API...", hud_testing_api_detail = "Vérification Gratuit vs Payant...",
		dlg_quota_title = "Diagnostic du Quota API", dlg_quota_body_fmt = "Fournisseur : %s\nModèle : %s\nRésultat : %s\nLot Calibré : %d textes\nDélai Anti-429 : %d ms",
		dlg_mods_title = "Mods Détectés et Progression",
		dlg_mods_empty_fmt = "Aucun autre mod traduisible trouvé (%s).",
		dlg_mods_header_fmt = "Langue Cible : %s (%s)\nCache Global : %d textes uniques | %d IDs appliqués\n------------------------------------------------------------",
		dlg_mods_native_lang = "Déjà dans la langue cible", dlg_mods_item_fmt = "%d. %s [%s]\n   Langue détectée : %s -> %s",
		hud_enabled_title = "HUD Activé", hud_enabled_detail = "L'indicateur s'affichera pendant les traductions.",
		dlg_retranslate_title = "Réanalyser / Vider le Cache", dlg_retranslate_confirm_fmt = "Voulez-vous vider TOUT le cache enregistré pour '%s' et tout retraduire ?\n\n(Choisissez 'Annuler' pour simplement rechercher les nouveaux textes.)",
	},

	-- ========================================================================
	-- DEUTSCH (GetLanguage() == "German")
	-- ========================================================================
	["de"] = {
		menu_button = "KI-ÜBERSETZER",
		hud_brand = "JA3 KI-ÜBERSETZER",
		mod_title = "JA3 KI-Übersetzer (Hintergrund-Auto-Übersetzer)",
		mod_desc = "Erkennt automatisch installierte/aktive Mods für Jagged Alliance 3, bestimmt deren Ausgangssprache und übersetzt alle Texte im Hintergrund direkt im Spiel per KI (Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio) ohne externe EXE-Datei.\n\n• Speichert und lädt alle Übersetzungen automatisch.\n• Erkennt Gratis- vs. Bezahl-API-Keys gegen Fehler 429.\n• Tastenkürzel im Spiel: Ctrl+Shift+T (oder Schaltfläche 'KI-ÜBERSETZER').",
		mod_changes = "Nativer Hintergrund-Übersetzer mit automatisch an die Spielsprache angepasster Oberfläche.",
		opt_auto_name = "Automatisch im Hintergrund übersetzen",
		opt_auto_help = "Erkennt und übersetzt ausstehende Mod-Texte automatisch im Hintergrund.",
		opt_lang_name = "Zielsprache der Übersetzung",
		opt_lang_help = "Wähle die Sprache, in die Mods im Spiel übersetzt werden sollen.",
		opt_choice_auto_lang = "Auto (Spielsprache)",
		opt_prov_name = "KI-Anbieter",
		opt_prov_help = "Verwendete KI-Engine. Drücke Ctrl+Shift+T zum Einfügen deines API-Keys.",
		opt_model_name = "KI-Modell",
		opt_model_help = "Wähle 'Auto (Im Panel gespeichert)' oder direkt ein Modell.",
		opt_choice_auto_model = "Auto (Im Panel gespeichert)",
		opt_scope_name = "Zu übersetzende Mods",
		opt_scope_help = "'Nur aktive Mods' oder 'Alle installierten Mods'.",
		opt_choice_scope_active = "Nur aktive Mods",
		opt_choice_scope_all = "Alle installierten Mods",
		opt_quota_name = "Auto-Kontingent (Gratis- vs. Bezahl-Key)",
		opt_quota_help = "Erkennt automatisch Free- vs. Paid-Tier und passt Paketgröße und Intervall gegen Fehler 429 an.",
		opt_desc_name = "Mod-Beschreibungen im MODS-Menü übersetzen",
		opt_desc_help = "Übersetzt Titel und Beschreibungen von Mods im In-Game-Mod-Manager in deine Sprache.",
		opt_hud_name = "Fortschrittsanzeige auf dem Bildschirm",
		opt_hud_help = "Zeigt oben rechts eine dezente Leiste während der Hintergrundübersetzung an.",
		badge_free = "[GRATIS-TARIF]", badge_paid = "[BEZAHL-TARIF]", badge_local = "[LOKALE KI]", badge_invalid = "[UNGÜLTIGER KEY]", badge_auto = "[AUTO]",
		tier_free_fmt = "Gratis-Tarif • Paket: %d • Intervall: %.1fs",
		tier_paid_fmt = "Bezahl-Tarif • Schnellmodus • Paket: %d • Intervall: %.2fs",
		tier_local_fmt = "Lokale Offline-KI • Kein Limit (Paket: %d)",
		tier_invalid = "Ungültiger oder abgelehnter API-Key",
		tier_missing_key = "Kein API-Key hinterlegt (Ctrl+Shift+T drücken)",
		tier_unknown = "Warte auf automatische Kontingenterkennung",
		provider_no_key_tag = " [Kein API-Key nötig]",
		btn_ok = "OK", btn_yes = "Ja", btn_cancel = "Abbrechen",
		key_not_set = "Nicht konfiguriert", key_set_short = "Konfiguriert (••••)", key_set_masked_fmt = "Konfiguriert (%s••••%s)",
		state_on = "Aktiviert", state_hidden = "Ausgeblendet", state_active = "Aktiv", state_inactive = "Inaktiv", state_idle = "Bereit", state_translating = "Übersetze...",
		status_init = "Initialisiere...", status_paused = "Pausiert", status_paused_user = "Vom Benutzer pausiert",
		status_restarting = "Scan wird neu gestartet...", status_switching_lang = "Zielsprache wird gewechselt...", status_clearing_cache = "Cache wird geleert...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T zum Fortsetzen)",
		status_auto_off_fmt = "Auto-Übersetzung deaktiviert (%d Texte geladen)",
		status_scanning = "Scanne installierte Mods...", hud_scanning_detail = "Prüfe Mod-Texte und Ausgangssprachen...",
		status_no_mods = "Keine weiteren übersetzbaren Mods aktiv", hud_no_mods_title = "Keine ausstehenden Mods", hud_no_mods_detail = "Aktiviere Mods im Mod-Manager für automatische Übersetzung.",
		status_done_fmt = "100%% Übersetzt (%d aktive Texte auf %s)", hud_all_done_title = "Mods zu 100% übersetzt!", hud_all_done_detail_fmt = "%d Texte auf %s angewendet.",
		status_need_key_fmt = "%d Texte offen • API-Key eingeben (Ctrl+Shift+T)", hud_need_key_title = "API-Key erforderlich", hud_need_key_detail_fmt = "%d neue Texte! Drücke Ctrl+Shift+T zum Einfügen deines API-Keys.",
		status_calibrating = "Prüfe API-Kontingent (Gratis vs. Bezahlt)...", hud_calibrating_title = "Kalibriere API-Kontingent...", hud_calibrating_detail_fmt = "%d neue Texte werden nach %s übersetzt...",
		status_invalid_key = "Ungültiger API-Key • Ctrl+Shift+T drücken", hud_invalid_key_title = "Ungültiger API-Key", hud_invalid_key_detail = "API-Key abgelehnt. Bitte über Ctrl+Shift+T aktualisieren.",
		status_batch_fmt = "%s: Paket %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Paket %d/%d (%d/%d Texte)",
		hud_saved_live_fmt = "Live gespeichert! %d/%d Texte nach %s übersetzt",
		hud_paused_quota_title = "Übersetzung pausiert", hud_finished_title = "Übersetzung abgeschlossen!", hud_finished_detail_fmt = "Alle aktiven Mods wurden nach %s übersetzt (%d Texte).",
		err_429_daily = "Tageslimit für dieses Modell erreicht. Drücke Ctrl+Shift+T für Modellwechsel.",
		wait_429_rpm_fmt = "Minutenlimit (429) • Automatische Fortsetzung in %ds...", wait_retry_fmt = "Verbinde erneut mit KI (Versuch %d/4)...",
		err_invalid_key_http_fmt = "Ungültiger API-Key (%s). Prüfe Ctrl+Shift+T.",
		panel_title_fmt = "JA3 KI-ÜBERSETZER v%s — Hintergrund-Panel (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUSE] Hintergrundübersetzung pausieren (%s)",
		menu_1_start = "1. [START] Mods jetzt im Hintergrund prüfen / übersetzen",
		menu_2_status_fmt = "2. [STATUS] %s | Cache: %d Texte",
		menu_3_key_fmt = "3. [API-KEY] API-Key einfügen oder ändern (%s)",
		menu_4_prov_fmt = "4. [ANBIETER] KI-Engine: %s",
		menu_5_model_fmt = "5. [MODELL] KI-Modell: %s (Von API abrufen)",
		menu_6_lang_fmt = "6. [SPRACHE] Zielsprache: %s -> %s",
		menu_7_quota_fmt = "7. [KONTINGENT] %s",
		menu_8_mods = "8. [MODS] Erkannte Mods, Ausgangssprache & Fortschritt",
		menu_9_hud_fmt = "9. [HUD] Fortschrittsanzeige oben rechts: %s",
		menu_desc_fmt = "10. [BESCHREIBUNGEN] Mod-Beschreibungen im MODS-Menü: %s",
		menu_11_retranslate = "11. [NEU ÜBERSETZEN] Neu scannen / Sprach-Cache leeren",
		menu_0_close = "0. Panel schließen (Übersetzung läuft im Hintergrund weiter)",
		dlg_status_title = "JA3 KI-Übersetzer Status",
		dlg_status_body_fmt = "Status: %s\nAnbieter: %s\nModell: %s\nAPI-Key: %s\nTarif: %s\nKalibrierung: Paket = %d Texte | Intervall = %d ms\nZielsprache: %s (%s)\nGespeichert: %d Einzeltexte (%d Spiel-IDs)",
		dlg_key_title_fmt = "API-Key — %s", dlg_key_placeholder = "API-Key hier mit Ctrl+V einfügen", dlg_key_desc_fmt = "Drücke Ctrl+V zum Einfügen deines Keys (%s).",
		hud_validating_key_title = "Prüfe API-Key...", hud_validating_key_detail = "Erkenne Gratis- vs. Bezahl-Tarif...",
		dlg_key_saved_title = "API-Key gespeichert & kalibriert", dlg_key_saved_body_fmt = "Anbieter: %s\nKey: %s\nErgebnis: %s\n\n%s",
		dlg_key_saved_ok = "Hintergrundübersetzung startet jetzt!", dlg_key_saved_check = "Bitte prüfe, ob der API-Key korrekt eingefügt wurde.",
		dlg_prov_title = "KI-Anbieter wählen", dlg_endpoint_title = "OpenAI-kompatibler Endpoint", dlg_endpoint_desc = "Basis-URL eingeben (z. B. http://localhost:8000/v1):",
		hud_fetching_models_title = "Lade Modelle...", hud_fetching_models_detail_fmt = "Frage verfügbare Modelle von %s ab...", dlg_model_title_fmt = "KI-Modell wählen oder eingeben (%s)",
		dlg_lang_title = "Zielsprache der Übersetzung",
		hud_testing_api_title = "Teste API...", hud_testing_api_detail = "Prüfe Gratis- vs. Bezahl-Tarif...",
		dlg_quota_title = "API-Kontingent Diagnose", dlg_quota_body_fmt = "Anbieter: %s\nModell: %s\nErgebnis: %s\nPaketgröße: %d Texte\nAnti-429-Intervall: %d ms",
		dlg_mods_title = "Erkannte Mods & Fortschritt",
		dlg_mods_empty_fmt = "Keine anderen übersetzbaren Mods im aktuellen Bereich (%s) gefunden.",
		dlg_mods_header_fmt = "Zielsprache: %s (%s)\nGlobaler Cache: %d Einzeltexte | %d IDs angewendet\n------------------------------------------------------------",
		dlg_mods_native_lang = "Bereits in Zielsprache", dlg_mods_item_fmt = "%d. %s [%s]\n   Erkannte Sprache: %s -> %s",
		hud_enabled_title = "HUD Aktiviert", hud_enabled_detail = "Die Fortschrittsleiste wird beim Übersetzen angezeigt.",
		dlg_retranslate_title = "Neu scannen / Cache leeren", dlg_retranslate_confirm_fmt = "Möchtest du den gesamten Cache für '%s' löschen und komplett neu übersetzen?\n\n('Abbrechen' wählen, um nur nach neuen Texten zu suchen.)",
	},

	-- ========================================================================
	-- РУССКИЙ (GetLanguage() == "Russian" | "Ukrainian")
	-- ========================================================================
	["ru"] = {
		menu_button = "ИИ-ПЕРЕВОДЧИК",
		hud_brand = "JA3 ИИ-ПЕРЕВОДЧИК",
		mod_title = "JA3 ИИ-Переводчик (Фоновый автоперевод модов)",
		mod_desc = "Автоматически обнаруживает установленные и активные моды Jagged Alliance 3, определяет исходный язык каждого мода и переводит все тексты в фоновом режиме прямо внутри игры с помощью ИИ (Google Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio) без внешних .exe файлов.\n\n• Автосохранение и мгновенное восстановление переводов.\n• Автоопределение бесплатного или платного ключа API (защита от ошибки 429).\n• Горячая клавиша в игре: Ctrl+Shift+T (или кнопка «ИИ-ПЕРЕВОДЧИК»).",
		mod_changes = "Полностью нативный фоновый переводчик с интерфейсом на языке игры.",
		opt_auto_name = "Автоперевод в фоновом режиме",
		opt_auto_help = "Автоматически находит и переводит тексты модов в фоне при запуске игры или включении мода.",
		opt_lang_name = "Целевой язык перевода",
		opt_lang_help = "Выберите язык, на который будут переводиться моды.",
		opt_choice_auto_lang = "Авто (Язык игры)",
		opt_prov_name = "Провайдер ИИ",
		opt_prov_help = "Движок ИИ для перевода. Нажмите Ctrl+Shift+T, чтобы вставить API-ключ.",
		opt_model_name = "Модель ИИ",
		opt_model_help = "Выберите «Авто (Из панели)» или укажите модель напрямую.",
		opt_choice_auto_model = "Авто (Из панели)",
		opt_scope_name = "Какие моды переводить",
		opt_scope_help = "«Только активные моды» или «Все установленные моды».",
		opt_choice_scope_active = "Только активные моды",
		opt_choice_scope_all = "Все установленные моды",
		opt_quota_name = "Автонастройка квоты (Бесплатный / Платный ключ)",
		opt_quota_help = "Определяет тип ключа API (Free/Paid) и подбирает размер пакета и паузу без ошибки 429.",
		opt_desc_name = "Переводить описания модов в меню МОДЫ",
		opt_desc_help = "Переводит названия и описания модов в игровом менеджере модов на ваш язык.",
		opt_hud_name = "Показывать индикатор прогресса на экране",
		opt_hud_help = "Показывает компактную панель в правом верхнем углу во время перевода.",
		badge_free = "[БЕСПЛАТНЫЙ]", badge_paid = "[ПЛАТНЫЙ]", badge_local = "[ЛОКАЛЬНЫЙ ИИ]", badge_invalid = "[НЕВЕРНЫЙ КЛЮЧ]", badge_auto = "[АВТО]",
		tier_free_fmt = "Бесплатный тариф • Пакет: %d • Пауза: %.1fс",
		tier_paid_fmt = "Платный тариф • Высокая скорость • Пакет: %d • Пауза: %.2fс",
		tier_local_fmt = "Локальный ИИ • Без лимитов (Пакет: %d)",
		tier_invalid = "Недействительный или отклонённый API-ключ",
		tier_missing_key = "API-ключ не задан (Нажмите Ctrl+Shift+T)",
		tier_unknown = "Ожидание проверки квоты API",
		provider_no_key_tag = " [Без ключа]",
		btn_ok = "ОК", btn_yes = "Да", btn_cancel = "Отмена",
		key_not_set = "Не задан", key_set_short = "Задан (••••)", key_set_masked_fmt = "Задан (%s••••%s)",
		state_on = "Включён", state_hidden = "Скрыт", state_active = "Активен", state_inactive = "Неактивен", state_idle = "Готов", state_translating = "Перевод...",
		status_init = "Инициализация...", status_paused = "Пауза", status_paused_user = "Приостановлено пользователем",
		status_restarting = "Перезапуск сканирования...", status_switching_lang = "Смена языка...", status_clearing_cache = "Очистка кэша...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T для продолжения)",
		status_auto_off_fmt = "Автоперевод выключен (применено %d сохранённых строк)",
		status_scanning = "Сканирование модов...", hud_scanning_detail = "Проверка текстов и исходного языка модов...",
		status_no_mods = "Нет других активных модов для перевода", hud_no_mods_title = "Нет модов в очереди", hud_no_mods_detail = "Включите моды в Менеджере модов для автоперевода.",
		status_done_fmt = "100%% Переведено (%d строк на %s)", hud_all_done_title = "Моды переведены на 100%!", hud_all_done_detail_fmt = "Применено %d строк (%s).",
		status_need_key_fmt = "Ожидает %d строк • Укажите API-ключ (Ctrl+Shift+T)", hud_need_key_title = "Требуется API-ключ", hud_need_key_detail_fmt = "Найдено %d новых строк! Нажмите Ctrl+Shift+T для ввода API-ключа.",
		status_calibrating = "Проверка квоты API (Free / Paid)...", hud_calibrating_title = "Калибровка квоты API...", hud_calibrating_detail_fmt = "%d новых строк для перевода на %s...",
		status_invalid_key = "Неверный API-ключ • Нажмите Ctrl+Shift+T", hud_invalid_key_title = "Неверный API-ключ", hud_invalid_key_detail = "Ключ отклонён провайдером. Обновите через Ctrl+Shift+T.",
		status_batch_fmt = "%s: пакет %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Пакет %d/%d (%d/%d строк)",
		hud_saved_live_fmt = "Сохранено! Переведено %d/%d строк (%s)",
		hud_paused_quota_title = "Перевод приостановлен", hud_finished_title = "Перевод завершён!", hud_finished_detail_fmt = "Все активные моды переведены на %s (%d строк).",
		err_429_daily = "Дневная квота модели исчерпана. Нажмите Ctrl+Shift+T для смены модели.",
		wait_429_rpm_fmt = "Лимит в минуту (429) • Продолжение через %dс...", wait_retry_fmt = "Переподключение к ИИ (попытка %d/4)...",
		err_invalid_key_http_fmt = "Неверный API-ключ (%s). Проверьте в Ctrl+Shift+T.",
		panel_title_fmt = "JA3 ИИ-ПЕРЕВОДЧИК v%s — Панель управления (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [ПАУЗА] Приостановить фоновый перевод (%s)",
		menu_1_start = "1. [СТАРТ] Перевести / Проверить моды сейчас",
		menu_2_status_fmt = "2. [СТАТУС] %s | Кэш: %d строк",
		menu_3_key_fmt = "3. [API-КЛЮЧ] Вставить или изменить ключ (%s)",
		menu_4_prov_fmt = "4. [ПРОВАЙДЕР] Движок ИИ: %s",
		menu_5_model_fmt = "5. [МОДЕЛЬ] Модель ИИ: %s (Загрузить список)",
		menu_6_lang_fmt = "6. [ЯЗЫК] Целевой язык: %s -> %s",
		menu_7_quota_fmt = "7. [КВОТА API] %s",
		menu_8_mods = "8. [МОДЫ] Список модов, исходный язык и прогресс",
		menu_9_hud_fmt = "9. [HUD] Индикатор в углу экрана: %s",
		menu_desc_fmt = "10. [ОПИСАНИЯ] Переводить описания в меню МОДЫ: %s",
		menu_11_retranslate = "11. [ПЕРЕПЕРЕВОД] Пересканировать / Очистить кэш языка",
		menu_0_close = "0. Закрыть панель (Перевод продолжится в фоне)",
		dlg_status_title = "Статус JA3 ИИ-Переводчика",
		dlg_status_body_fmt = "Состояние: %s\nПровайдер: %s\nМодель: %s\nAPI-ключ: %s\nТариф: %s\nКалибровка: Пакет = %d строк | Интервал = %d мс\nЦелевой язык: %s (%s)\nСохранено на диске: %d уникальных строк (%d ID)",
		dlg_key_title_fmt = "API-ключ — %s", dlg_key_placeholder = "Вставьте API-ключ с помощью Ctrl+V", dlg_key_desc_fmt = "Нажмите Ctrl+V для вставки ключа (%s).",
		hud_validating_key_title = "Проверка API-ключа...", hud_validating_key_detail = "Определение бесплатного / платного тарифа...",
		dlg_key_saved_title = "API-ключ сохранён и настроен", dlg_key_saved_body_fmt = "Провайдер: %s\nКлюч: %s\nРезультат: %s\n\n%s",
		dlg_key_saved_ok = "Фоновый перевод запускается!", dlg_key_saved_check = "Проверьте правильность введённого ключа.",
		dlg_prov_title = "Выберите провайдера ИИ", dlg_endpoint_title = "OpenAI-совместимый Endpoint", dlg_endpoint_desc = "Введите базовый URL (например http://localhost:8000/v1):",
		hud_fetching_models_title = "Загрузка моделей...", hud_fetching_models_detail_fmt = "Запрос доступных моделей у %s...", dlg_model_title_fmt = "Выберите или введите модель ИИ (%s)",
		dlg_lang_title = "Целевой язык перевода",
		hud_testing_api_title = "Проверка API...", hud_testing_api_detail = "Тест квоты Free vs Paid...",
		dlg_quota_title = "Диагностика квоты API", dlg_quota_body_fmt = "Провайдер: %s\nМодель: %s\nРезультат: %s\nРазмер пакета: %d строк\nИнтервал Anti-429: %d мс",
		dlg_mods_title = "Обнаруженные моды и прогресс",
		dlg_mods_empty_fmt = "Другие переводимые моды не найдены (%s).",
		dlg_mods_header_fmt = "Целевой язык: %s (%s)\nГлобальный кэш: %d строк | %d ID применено\n------------------------------------------------------------",
		dlg_mods_native_lang = "Уже на целевом языке", dlg_mods_item_fmt = "%d. %s [%s]\n   Исходный язык: %s -> %s",
		hud_enabled_title = "HUD Включён", hud_enabled_detail = "Индикатор прогресса будет отображаться при переводе.",
		dlg_retranslate_title = "Пересканировать / Очистить кэш", dlg_retranslate_confirm_fmt = "Удалить ВЕСЬ сохранённый кэш для «%s» и перевести заново?\n\n(Нажмите «Отмена», чтобы просто найти новые строки, сохранив готовый перевод.)",
	},

	-- ========================================================================
	-- POLSKI (GetLanguage() == "Polish")
	-- ========================================================================
	["pl"] = {
		menu_button = "TŁUMACZ AI",
		hud_brand = "JA3 TŁUMACZ AI",
		mod_title = "JA3 Tłumacz AI (Automatyczne tłumaczenie w tle)",
		mod_desc = "Automatycznie wykrywa zainstalowane/aktywne mody do Jagged Alliance 3, rozpoznaje ich język źródłowy i tłumaczy wszystkie teksty w tle bezpośrednio w grze przy użyciu AI (Gemini, OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio) bez zewnętrznych plików .exe.\n\n• Automatyczny zapis i przywracanie tłumaczeń.\n• Wykrywanie darmowego vs płatnego klucza API (ochrona przed błędem 429).\n• Skrót w grze: Ctrl+Shift+T (lub przycisk 'TŁUMACZ AI').",
		mod_changes = "Natywny tłumacz w tle z interfejsem dopasowanym do języka gry.",
		opt_auto_name = "Automatyczne tłumaczenie w tle",
		opt_auto_help = "Automatycznie wykrywa i tłumaczy teksty modów w tle.",
		opt_lang_name = "Docelowy język tłumaczenia",
		opt_lang_help = "Wybierz język, na który mają być tłumaczone mody.",
		opt_choice_auto_lang = "Auto (Język gry)",
		opt_prov_name = "Dostawca AI",
		opt_prov_help = "Silnik AI. Naciśnij Ctrl+Shift+T, aby wkleić klucz API.",
		opt_model_name = "Model AI",
		opt_model_help = "Wybierz 'Auto (Zapisany w panelu)' lub wskaż model.",
		opt_choice_auto_model = "Auto (Zapisany w panelu)",
		opt_scope_name = "Które mody tłumaczyć",
		opt_scope_help = "'Tylko aktywne mody' lub 'Wszystkie zainstalowane mody'.",
		opt_choice_scope_active = "Tylko aktywne mody",
		opt_choice_scope_all = "Wszystkie zainstalowane mody",
		opt_quota_name = "Auto-kalibracja limitu (Klucz Darmowy vs Płatny)",
		opt_quota_help = "Automatycznie wykrywa typ klucza API i dobiera wielkość paczki oraz odstęp przeciw błędom 429.",
		opt_desc_name = "Tłumacz opisy modów w menu MODS",
		opt_desc_help = "Tłumaczy tytuły i opisy modów w menedżerze modów na Twój język.",
		opt_hud_name = "Pokaż pasek postępu na ekranie",
		opt_hud_help = "Wyświetla dyskretny wskaźnik w prawym górnym rogu podczas tłumaczenia.",
		badge_free = "[DARMOWY]", badge_paid = "[PŁATNY]", badge_local = "[LOKALNE AI]", badge_invalid = "[BŁĘDNY KLUCZ]", badge_auto = "[AUTO]",
		tier_free_fmt = "Klucz Darmowy • Paczka: %d • Odstęp: %.1fs",
		tier_paid_fmt = "Klucz Płatny • Szybki tryb • Paczka: %d • Odstęp: %.2fs",
		tier_local_fmt = "Lokalne AI Offline • Bez limitu (Paczka: %d)",
		tier_invalid = "Nieprawidłowy lub odrzucony klucz API",
		tier_missing_key = "Brak klucza API (Naciśnij Ctrl+Shift+T)",
		tier_unknown = "Oczekiwanie na wykrycie limitu API",
		provider_no_key_tag = " [Bez klucza API]",
		btn_ok = "OK", btn_yes = "Tak", btn_cancel = "Anuluj",
		key_not_set = "Nie skonfigurowano", key_set_short = "Skonfigurowano (••••)", key_set_masked_fmt = "Skonfigurowano (%s••••%s)",
		state_on = "Włączony", state_hidden = "Ukryty", state_active = "Aktywny", state_inactive = "Nieaktywny", state_idle = "Gotowy", state_translating = "Tłumaczenie...",
		status_init = "Inicjalizacja...", status_paused = "Wstrzymano", status_paused_user = "Wstrzymano przez gracza",
		status_restarting = "Ponowne skanowanie...", status_switching_lang = "Zmiana języka...", status_clearing_cache = "Czyszczenie pamięci...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T aby wznowić)",
		status_auto_off_fmt = "Auto-tłumaczenie wyłączone (%d zapisanych tekstów)",
		status_scanning = "Skanowanie modów...", hud_scanning_detail = "Sprawdzanie tekstów i języków źródłowych...",
		status_no_mods = "Brak innych aktywnych modów do przetłumaczenia", hud_no_mods_title = "Brak modów", hud_no_mods_detail = "Włącz mody w Menedżerze modów, aby przetłumaczyć je automatycznie.",
		status_done_fmt = "100%% Przetłumaczono (%d tekstów: %s)", hud_all_done_title = "Mody przetłumaczone w 100%!", hud_all_done_detail_fmt = "Zastosowano %d tekstów (%s).",
		status_need_key_fmt = "%d tekstów oczekuje • Podaj klucz API (Ctrl+Shift+T)", hud_need_key_title = "Wymagany klucz API", hud_need_key_detail_fmt = "Wykryto %d nowych tekstów! Naciśnij Ctrl+Shift+T, aby wkleić klucz API.",
		status_calibrating = "Sprawdzanie limitu API...", hud_calibrating_title = "Kalibracja limitu API...", hud_calibrating_detail_fmt = "%d nowych tekstów do tłumaczenia na %s...",
		status_invalid_key = "Błędny klucz API • Naciśnij Ctrl+Shift+T", hud_invalid_key_title = "Błędny klucz API", hud_invalid_key_detail = "Klucz odrzucony. Zaktualizuj go przez Ctrl+Shift+T.",
		status_batch_fmt = "%s: paczka %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Paczka %d/%d (%d/%d tekstów)",
		hud_saved_live_fmt = "Zapisano na żywo! %d/%d tekstów na %s",
		hud_paused_quota_title = "Tłumaczenie wstrzymane", hud_finished_title = "Tłumaczenie ukończone!", hud_finished_detail_fmt = "Wszystkie aktywne mody przetłumaczone na %s (%d tekstów).",
		err_429_daily = "Osiągnięto dzienny limit tego modelu. Naciśnij Ctrl+Shift+T, aby zmienić model.",
		wait_429_rpm_fmt = "Limit minutowy (429) • Wznowienie za %ds...", wait_retry_fmt = "Ponowne łączenie z AI (próba %d/4)...",
		err_invalid_key_http_fmt = "Nieprawidłowy klucz API (%s). Sprawdź Ctrl+Shift+T.",
		panel_title_fmt = "JA3 TŁUMACZ AI v%s — Panel w tle (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [PAUZA] Wstrzymaj tłumaczenie w tle (%s)",
		menu_1_start = "1. [START] Tłumacz / Skanuj mody teraz",
		menu_2_status_fmt = "2. [STATUS] %s | Pamięć: %d tekstów",
		menu_3_key_fmt = "3. [KLUCZ API] Wklej lub zmień klucz API (%s)",
		menu_4_prov_fmt = "4. [DOSTAWCA] Silnik AI: %s",
		menu_5_model_fmt = "5. [MODEL] Model AI: %s (Pobierz z API)",
		menu_6_lang_fmt = "6. [JĘZYK] Język docelowy: %s -> %s",
		menu_7_quota_fmt = "7. [LIMIT API] %s",
		menu_8_mods = "8. [MODY] Wykryte mody, język źródłowy i postęp",
		menu_9_hud_fmt = "9. [HUD] Wskaźnik w rogu ekranu: %s",
		menu_desc_fmt = "10. [OPISY] Tłumacz opisy w menu MODS: %s",
		menu_11_retranslate = "11. [PRZETŁUMACZ PONOWNIE] Skanuj / Wyczyść pamięć języka",
		menu_0_close = "0. Zamknij panel (Tłumaczenie trwa dalej w tle)",
		dlg_status_title = "Status JA3 Tłumacza AI",
		dlg_status_body_fmt = "Stan: %s\nDostawca: %s\nModel: %s\nKlucz API: %s\nProfil limitu: %s\nKalibracja: Paczka = %d tekstów | Odstęp = %d ms\nJęzyk docelowy: %s (%s)\nZapisano na dysku: %d unikalnych tekstów (%d ID)",
		dlg_key_title_fmt = "Klucz API — %s", dlg_key_placeholder = "Wklej klucz API tutaj (Ctrl+V)", dlg_key_desc_fmt = "Naciśnij Ctrl+V, aby wkleić klucz (%s).",
		hud_validating_key_title = "Weryfikacja klucza API...", hud_validating_key_detail = "Wykrywanie limitu Darmowy vs Płatny...",
		dlg_key_saved_title = "Klucz API zapisany", dlg_key_saved_body_fmt = "Dostawca: %s\nKlucz: %s\nWynik: %s\n\n%s",
		dlg_key_saved_ok = "Tłumaczenie w tle zostanie uruchomione!", dlg_key_saved_check = "Sprawdź, czy klucz został poprawnie wklejony.",
		dlg_prov_title = "Wybierz dostawcę AI", dlg_endpoint_title = "Endpoint zgodny z OpenAI", dlg_endpoint_desc = "Podaj bazowy URL (np. http://localhost:8000/v1):",
		hud_fetching_models_title = "Pobieranie modeli...", hud_fetching_models_detail_fmt = "Pobieranie listy modeli z %s...", dlg_model_title_fmt = "Wybierz lub wpisz model AI (%s)",
		dlg_lang_title = "Docelowy język tłumaczenia",
		hud_testing_api_title = "Testowanie API...", hud_testing_api_detail = "Sprawdzanie Darmowy vs Płatny...",
		dlg_quota_title = "Diagnostyka limitu API", dlg_quota_body_fmt = "Dostawca: %s\nModel: %s\nWynik: %s\nRozmiar paczki: %d tekstów\nOdstęp Anti-429: %d ms",
		dlg_mods_title = "Wykryte mody i postęp",
		dlg_mods_empty_fmt = "Nie znaleziono innych modów do tłumaczenia (%s).",
		dlg_mods_header_fmt = "Język docelowy: %s (%s)\nZapisana pamięć: %d unikalnych tekstów | %d ID\n------------------------------------------------------------",
		dlg_mods_native_lang = "Już w języku docelowym", dlg_mods_item_fmt = "%d. %s [%s]\n   Wykryty język: %s -> %s",
		hud_enabled_title = "HUD Włączony", hud_enabled_detail = "Pasek postępu będzie widoczny podczas tłumaczenia.",
		dlg_retranslate_title = "Skanuj / Wyczyść pamięć", dlg_retranslate_confirm_fmt = "Czy chcesz wyczyścić CAŁĄ pamięć tłumaczeń dla '%s' i przetłumaczyć od nowa?\n\n(Wybierz 'Anuluj', aby tylko doskanować nowe teksty.)",
	},

	-- ========================================================================
	-- BAHASA INDONESIA (GetLanguage() == "Indonesian")
	-- ========================================================================
	["id"] = {
		menu_button = "PENERJEMAH AI",
		hud_brand = "JA3 PENERJEMAH AI",
		mod_title = "JA3 Penerjemah AI (Auto-Terjemahan Latar Belakang)",
		mod_desc = "Mendeteksi otomatis mod Jagged Alliance 3 yang terpasang/aktif, mengenali bahasa asli setiap mod, dan menerjemahkan semua teks di latar belakang langsung di dalam game menggunakan AI tanpa file .exe eksternal.\n\n• Menyimpan & memulihkan terjemahan secara otomatis.\n• Deteksi otomatis API Key Gratis vs Berbayar (anti-error 429).\n• Pintasan dalam game: Ctrl+Shift+T (atau tombol 'PENERJEMAH AI').",
		mod_changes = "Penerjemah latar belakang asli dengan antarmuka mengikuti bahasa game.",
		opt_auto_name = "Terjemahkan Otomatis di Latar Belakang",
		opt_auto_help = "Secara otomatis mendeteksi dan menerjemahkan teks mod di latar belakang.",
		opt_lang_name = "Bahasa Tujuan Terjemahan",
		opt_lang_help = "Pilih bahasa tujuan terjemahan mod di dalam game.",
		opt_choice_auto_lang = "Otomatis (Bahasa Game)",
		opt_prov_name = "Penyedia AI",
		opt_prov_help = "Mesin AI yang digunakan. Tekan Ctrl+Shift+T untuk menempelkan API Key.",
		opt_model_name = "Model AI",
		opt_model_help = "Pilih 'Otomatis (Tersimpan di Panel)' atau pilih model langsung.",
		opt_choice_auto_model = "Otomatis (Tersimpan di Panel)",
		opt_scope_name = "Mod yang Diterjemahkan",
		opt_scope_help = "'Hanya Mod Aktif' atau 'Semua Mod Terpasang'.",
		opt_choice_scope_active = "Hanya Mod Aktif",
		opt_choice_scope_all = "Semua Mod Terpasang",
		opt_quota_name = "Kalibrasi Kuota Otomatis (Gratis vs Berbayar)",
		opt_quota_help = "Mendeteksi API key Gratis atau Berbayar dan mengatur ukuran batch & jeda agar bebas error 429.",
		opt_desc_name = "Terjemahkan Deskripsi Mod di Menu MODS",
		opt_desc_help = "Menerjemahkan judul dan deskripsi mod di Manajer Mod dalam game ke bahasa Anda.",
		opt_hud_name = "Tampilkan Indikator Progres di Layar",
		opt_hud_help = "Menampilkan bar kecil di kanan atas saat menerjemahkan di latar belakang.",
		badge_free = "[KUOTA GRATIS]", badge_paid = "[BERBAYAR]", badge_local = "[AI LOKAL]", badge_invalid = "[KEY TIDAK VALID]", badge_auto = "[AUTO]",
		tier_free_fmt = "Kuota Gratis • Batch: %d • Jeda: %.1fd",
		tier_paid_fmt = "Kuota Berbayar • Cepat • Batch: %d • Jeda: %.2fd",
		tier_local_fmt = "AI Lokal Offline • Tanpa Batas (Batch: %d)",
		tier_invalid = "API Key tidak valid atau ditolak",
		tier_missing_key = "API Key belum diatur (Tekan Ctrl+Shift+T)",
		tier_unknown = "Menunggu deteksi kuota otomatis",
		provider_no_key_tag = " [Tanpa API Key]",
		btn_ok = "OK", btn_yes = "Ya", btn_cancel = "Batal",
		key_not_set = "Belum diatur", key_set_short = "Tersimpan (••••)", key_set_masked_fmt = "Tersimpan (%s••••%s)",
		state_on = "Aktif", state_hidden = "Tersembunyi", state_active = "Aktif", state_inactive = "Nonaktif", state_idle = "Siap", state_translating = "Menerjemahkan...",
		status_init = "Menginisialisasi...", status_paused = "Dijeda", status_paused_user = "Dijeda oleh pengguna",
		status_restarting = "Memulai ulang pemindaian...", status_switching_lang = "Mengganti bahasa...", status_clearing_cache = "Menghapus cache...",
		hud_paused_detail_fmt = "%s (Ctrl+Shift+T untuk lanjut)",
		status_auto_off_fmt = "Terjemahan otomatis nonaktif (%d teks diterapkan)",
		status_scanning = "Memindai mod terpasang...", hud_scanning_detail = "Memeriksa teks dan bahasa asli mod...",
		status_no_mods = "Tidak ada mod lain yang perlu diterjemahkan", hud_no_mods_title = "Tidak ada mod tertunda", hud_no_mods_detail = "Aktifkan mod di Mod Manager untuk diterjemahkan otomatis.",
		status_done_fmt = "100%% Diterjemahkan (%d teks aktif dalam %s)", hud_all_done_title = "Mod 100% Diterjemahkan!", hud_all_done_detail_fmt = "%d teks diterapkan dalam %s.",
		status_need_key_fmt = "%d teks tertunda • Atur API Key (Ctrl+Shift+T)", hud_need_key_title = "API Key Diperlukan", hud_need_key_detail_fmt = "%d teks baru ditemukan! Tekan Ctrl+Shift+T untuk menempel API Key.",
		status_calibrating = "Memeriksa kuota API...", hud_calibrating_title = "Kalibrasi Kuota API...", hud_calibrating_detail_fmt = "%d teks baru akan diterjemahkan ke %s...",
		status_invalid_key = "API Key tidak valid • Tekan Ctrl+Shift+T", hud_invalid_key_title = "API Key Tidak Valid", hud_invalid_key_detail = "API Key ditolak penyedia. Perbarui lewat Ctrl+Shift+T.",
		status_batch_fmt = "%s: batch %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • Batch %d/%d (%d/%d teks)",
		hud_saved_live_fmt = "Tersimpan langsung! %d/%d teks ke %s",
		hud_paused_quota_title = "Terjemahan Dijeda", hud_finished_title = "Terjemahan Selesai!", hud_finished_detail_fmt = "Semua mod aktif telah diterjemahkan ke %s (%d teks).",
		err_429_daily = "Kuota harian model ini habis. Tekan Ctrl+Shift+T untuk mengganti model.",
		wait_429_rpm_fmt = "Batas per menit (429) • Lanjut otomatis dalam %dd...", wait_retry_fmt = "Menghubungkan ulang ke AI (percobaan %d/4)...",
		err_invalid_key_http_fmt = "API Key tidak valid (%s). Periksa Ctrl+Shift+T.",
		panel_title_fmt = "JA3 PENERJEMAH AI v%s — Panel Latar Belakang (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [JEDA] Jeda Terjemahan Latar Belakang (%s)",
		menu_1_start = "1. [MULAI] Terjemahkan / Pindai Mod Sekarang",
		menu_2_status_fmt = "2. [STATUS] %s | Cache: %d teks",
		menu_3_key_fmt = "3. [API KEY] Tempel atau Ubah API Key (%s)",
		menu_4_prov_fmt = "4. [PENYEDIA] Mesin AI: %s",
		menu_5_model_fmt = "5. [MODEL] Model AI: %s (Ambil dari API)",
		menu_6_lang_fmt = "6. [BAHASA] Bahasa Tujuan: %s -> %s",
		menu_7_quota_fmt = "7. [KUOTA AI] %s",
		menu_8_mods = "8. [MOD] Lihat Mod Terdeteksi, Bahasa Asli & Progres",
		menu_9_hud_fmt = "9. [HUD] Indikator Sudut Layar: %s",
		menu_desc_fmt = "10. [DESKRIPSI] Terjemahkan Deskripsi di Menu MODS: %s",
		menu_11_retranslate = "11. [TERJEMAH ULANG] Pindai Ulang / Hapus Cache Bahasa",
		menu_0_close = "0. Tutup Panel (Terjemahan tetap berjalan di latar belakang)",
		dlg_status_title = "Status JA3 Penerjemah AI",
		dlg_status_body_fmt = "Status: %s\nPenyedia: %s\nModel: %s\nAPI Key: %s\nKuota: %s\nKalibrasi: Batch = %d teks | Jeda = %d ms\nBahasa Tujuan: %s (%s)\nTersimpan di Disk: %d teks unik (%d ID)",
		dlg_key_title_fmt = "API Key — %s", dlg_key_placeholder = "Tempel API Key di sini dengan Ctrl+V", dlg_key_desc_fmt = "Tekan Ctrl+V untuk menempel API Key (%s).",
		hud_validating_key_title = "Memvalidasi API Key...", hud_validating_key_detail = "Mendeteksi kuota Gratis vs Berbayar...",
		dlg_key_saved_title = "API Key Disimpan", dlg_key_saved_body_fmt = "Penyedia: %s\nKey: %s\nHasil: %s\n\n%s",
		dlg_key_saved_ok = "Terjemahan latar belakang dimulai!", dlg_key_saved_check = "Pastikan API Key sudah ditempel dengan benar.",
		dlg_prov_title = "Pilih Penyedia AI", dlg_endpoint_title = "Endpoint Kompatibel OpenAI", dlg_endpoint_desc = "Masukkan URL dasar (mis. http://localhost:8000/v1):",
		hud_fetching_models_title = "Mengambil model...", hud_fetching_models_detail_fmt = "Mengambil daftar model dari %s...", dlg_model_title_fmt = "Pilih atau Ketik Model AI (%s)",
		dlg_lang_title = "Bahasa Tujuan Terjemahan",
		hud_testing_api_title = "Menguji API...", hud_testing_api_detail = "Memeriksa Gratis vs Berbayar...",
		dlg_quota_title = "Diagnostik Kuota API", dlg_quota_body_fmt = "Penyedia: %s\nModel: %s\nHasil: %s\nBatch: %d teks\nJeda Anti-429: %d ms",
		dlg_mods_title = "Mod Terdeteksi & Progres",
		dlg_mods_empty_fmt = "Tidak ada mod lain yang ditemukan (%s).",
		dlg_mods_header_fmt = "Bahasa Tujuan: %s (%s)\nCache Global: %d teks unik | %d ID diterapkan\n------------------------------------------------------------",
		dlg_mods_native_lang = "Sudah dalam bahasa tujuan", dlg_mods_item_fmt = "%d. %s [%s]\n   Bahasa asli: %s -> %s",
		hud_enabled_title = "HUD Aktif", hud_enabled_detail = "Indikator progres akan tampil saat menerjemahkan.",
		dlg_retranslate_title = "Pindai Ulang / Hapus Cache", dlg_retranslate_confirm_fmt = "Hapus SEMUA cache tersimpan untuk '%s' dan terjemahkan ulang dari awal?\n\n(Pilih 'Batal' untuk hanya memindai teks baru.)",
	},

	-- ========================================================================
	-- 简体中文 (GetLanguage() == "Schinese")
	-- ========================================================================
	["zh-CN"] = {
		menu_button = "AI 模组翻译器",
		hud_brand = "JA3 AI 模组翻译器",
		mod_title = "JA3 AI 模组翻译器（后台自动翻译）",
		mod_desc = "自动检测《铁血联盟3》已安装/已启用的模组，识别模组原始语言，并在游戏内后台通过 AI（Google Gemini、OpenAI、OpenRouter、Groq、DeepSeek、Ollama、LM Studio）直接实时翻译所有文本，无需任何外部 exe 程序。\n\n• 自动保存并在启动时瞬间恢复所有已翻译内容。\n• 自动识别免费版与付费版 API Key，智能调节批次与间隔防止 429 超限。\n• 游戏内快捷键：Ctrl+Shift+T（或点击菜单中的“AI 模组翻译器”）。",
		mod_changes = "纯原生游戏内后台自动翻译，界面自动跟随游戏语言，支持免费/付费配额自适应。",
		opt_auto_name = "后台自动翻译模组",
		opt_auto_help = "启用后，进入游戏或启用模组时自动在后台检测并翻译未翻译的模组文本。",
		opt_lang_name = "目标翻译语言",
		opt_lang_help = "选择将模组翻译为哪种目标语言。",
		opt_choice_auto_lang = "自动（跟随游戏语言）",
		opt_prov_name = "AI 服务商",
		opt_prov_help = "翻译使用的 AI 引擎。按 Ctrl+Shift+T 粘贴您的 API Key。",
		opt_model_name = "AI 模型",
		opt_model_help = "选择“自动（使用面板保存的模型）”或直接指定常用模型。",
		opt_choice_auto_model = "自动（使用面板保存的模型）",
		opt_scope_name = "翻译模组范围",
		opt_scope_help = "“仅已启用模组”只翻译当前生效模组；“所有已安装模组”还会预翻译未启用模组。",
		opt_choice_scope_active = "仅已启用模组",
		opt_choice_scope_all = "所有已安装模组",
		opt_quota_name = "自动配额校准（免费 vs 付费 Key）",
		opt_quota_help = "自动检测 API Key 为免费层还是付费层，并自动调整每批条数与请求间隔以避免 429 错误。",
		opt_desc_name = "翻译 MODS 菜单中的模组描述",
		opt_desc_help = "将游戏内模组管理器中的模组标题和描述翻译为您的语言。",
		opt_hud_name = "显示右上角后台进度条",
		opt_hud_help = "后台翻译时在屏幕右上角显示精简进度提示，完成后自动隐藏。",
		badge_free = "[免费配额]", badge_paid = "[付费配额]", badge_local = "[本地 AI]", badge_invalid = "[密钥无效]", badge_auto = "[自动]",
		tier_free_fmt = "免费配额 (Free Tier) • 每批: %d • 间隔: %.1f秒",
		tier_paid_fmt = "付费配额 (Paid Tier) • 高速模式 • 每批: %d • 间隔: %.2f秒",
		tier_local_fmt = "本地离线 AI • 无配额限制（每批: %d）",
		tier_invalid = "API Key 无效或被拒绝",
		tier_missing_key = "未配置 API Key（请按 Ctrl+Shift+T）",
		tier_unknown = "等待自动检测 API 配额",
		provider_no_key_tag = " [免密钥]",
		btn_ok = "确定", btn_yes = "是", btn_cancel = "取消",
		key_not_set = "未设置", key_set_short = "已设置 (••••)", key_set_masked_fmt = "已设置 (%s••••%s)",
		state_on = "已开启", state_hidden = "已隐藏", state_active = "已启用", state_inactive = "未启用", state_idle = "就绪", state_translating = "翻译中...",
		status_init = "正在初始化...", status_paused = "已暂停", status_paused_user = "用户已暂停",
		status_restarting = "正在重新扫描...", status_switching_lang = "正在切换目标语言...", status_clearing_cache = "正在清理缓存...",
		hud_paused_detail_fmt = "%s（按 Ctrl+Shift+T 继续）",
		status_auto_off_fmt = "自动翻译已关闭（已加载 %d 条缓存译文）",
		status_scanning = "正在扫描已安装模组...", hud_scanning_detail = "正在检查模组文本并识别源语言...",
		status_no_mods = "当前没有其他需要翻译的模组", hud_no_mods_title = "无待翻译模组", hud_no_mods_detail = "在模组管理器中启用模组后将自动后台翻译。",
		status_done_fmt = "100%% 已翻译（%d 条文本已生效 · %s）", hud_all_done_title = "模组已 100% 翻译完成！", hud_all_done_detail_fmt = "已应用 %d 条译文（%s）。",
		status_need_key_fmt = "%d 条待翻译 • 请按 Ctrl+Shift+T 设置 API Key", hud_need_key_title = "需要配置 API Key", hud_need_key_detail_fmt = "发现 %d 条新文本！请按 Ctrl+Shift+T 粘贴 API Key。",
		status_calibrating = "正在检测 API 配额（免费 vs 付费）...", hud_calibrating_title = "正在校准 API 配额...", hud_calibrating_detail_fmt = "准备将 %d 条新文本翻译为 %s...",
		status_invalid_key = "API Key 无效 • 请按 Ctrl+Shift+T 修改", hud_invalid_key_title = "API Key 无效", hud_invalid_key_detail = "密钥被服务商拒绝，请按 Ctrl+Shift+T 更新。",
		status_batch_fmt = "%s：批次 %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • 批次 %d/%d（%d/%d 条）",
		hud_saved_live_fmt = "实时已保存！%d/%d 条已翻译为 %s",
		hud_paused_quota_title = "翻译已暂停", hud_finished_title = "翻译全部完成！", hud_finished_detail_fmt = "所有启用模组已翻译为 %s（共保存 %d 条）。",
		err_429_daily = "当前模型今日免费额度已用尽。请按 Ctrl+Shift+T 切换模型。",
		wait_429_rpm_fmt = "触发每分钟限速 (429) • %d 秒后自动继续...", wait_retry_fmt = "正在重连 AI（第 %d/4 次）...",
		err_invalid_key_http_fmt = "API Key 无效或无权限 (%s)，请按 Ctrl+Shift+T 检查。",
		panel_title_fmt = "JA3 AI 模组翻译器 v%s — 后台控制面板 (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [暂停] 暂停后台翻译（%s）",
		menu_1_start = "1. [开始] 立即在后台扫描并翻译模组",
		menu_2_status_fmt = "2. [状态] %s | 已缓存：%d 条",
		menu_3_key_fmt = "3. [API KEY] 粘贴或修改密钥（%s）",
		menu_4_prov_fmt = "4. [服务商] AI 引擎：%s",
		menu_5_model_fmt = "5. [模型] AI 模型：%s（从 API 获取列表）",
		menu_6_lang_fmt = "6. [语言] 目标语言：%s -> %s",
		menu_7_quota_fmt = "7. [配额检测] %s",
		menu_8_mods = "8. [模组报告] 查看已检测模组、源语言与翻译进度",
		menu_9_hud_fmt = "9. [HUD 提示] 右上角进度指示器：%s",
		menu_desc_fmt = "10. [模组描述] 翻译 MODS 菜单中的模组描述：%s",
		menu_11_retranslate = "11. [重新翻译] 重新扫描 / 清空当前语言缓存",
		menu_0_close = "0. 关闭面板（翻译将在后台继续运行）",
		dlg_status_title = "JA3 AI 模组翻译器状态",
		dlg_status_body_fmt = "当前状态：%s\nAI 服务商：%s\n当前模型：%s\nAPI Key：%s\n配额类型：%s\n当前参数：每批 = %d 条 | 最小间隔 = %d ms\n实际目标语言：%s (%s)\n磁盘已保存：%d 条唯一译文（%d 个游戏 ID）",
		dlg_key_title_fmt = "API Key — %s", dlg_key_placeholder = "按 Ctrl+V 在此粘贴您的 API Key", dlg_key_desc_fmt = "请按 Ctrl+V 粘贴密钥 (%s)，将安全保存在 AppData/JA3TradutorIA。",
		hud_validating_key_title = "正在验证 API Key...", hud_validating_key_detail = "正在自动识别免费版 / 付费版配额...",
		dlg_key_saved_title = "API Key 已保存并完成校准", dlg_key_saved_body_fmt = "服务商：%s\n密钥：%s\n检测结果：%s\n\n%s",
		dlg_key_saved_ok = "后台自动翻译即将开始！", dlg_key_saved_check = "请检查密钥是否粘贴正确。",
		dlg_prov_title = "选择 AI 服务商", dlg_endpoint_title = "OpenAI 兼容接口地址", dlg_endpoint_desc = "请输入基础 URL（例如 http://localhost:8000/v1）：",
		hud_fetching_models_title = "正在查询模型...", hud_fetching_models_detail_fmt = "正在从 %s 获取可用模型列表...", dlg_model_title_fmt = "选择或输入 AI 模型 (%s)",
		dlg_lang_title = "选择目标翻译语言",
		hud_testing_api_title = "正在测试 API...", hud_testing_api_detail = "正在检测免费 / 付费配额...",
		dlg_quota_title = "API 配额诊断结果", dlg_quota_body_fmt = "服务商：%s\n模型：%s\n诊断：%s\n每批数量：%d 条\n防 429 间隔：%d ms",
		dlg_mods_title = "已检测模组与翻译进度",
		dlg_mods_empty_fmt = "当前范围（%s）未发现其他可翻译模组。",
		dlg_mods_header_fmt = "目标语言：%s (%s)\n全局缓存：%d 条唯一译文 | %d 个已应用 ID\n------------------------------------------------------------",
		dlg_mods_native_lang = "已为目标语言", dlg_mods_item_fmt = "%d. %s [%s]\n   识别语言：%s -> %s",
		hud_enabled_title = "HUD 已开启", hud_enabled_detail = "后台翻译时将在右上角显示进度。",
		dlg_retranslate_title = "重新扫描 / 清空缓存", dlg_retranslate_confirm_fmt = "确定要清空“%s”的全部已保存译文并从头重新翻译吗？\n\n（点击“取消”则保留现有译文，仅扫描新增文本。）",
	},

	-- ========================================================================
	-- 繁體中文 (GetLanguage() == "Tchinese")
	-- ========================================================================
	["zh-TW"] = {
		menu_button = "AI 模組翻譯器",
		hud_brand = "JA3 AI 模組翻譯器",
		mod_title = "JA3 AI 模組翻譯器（背景自動翻譯）",
		mod_desc = "自動偵測《鐵血聯盟3》已安裝/已啟用的模組，識別原始語言，並在遊戲內背景透過 AI（Google Gemini、OpenAI、OpenRouter、Groq、DeepSeek、Ollama、LM Studio）直接即時翻譯所有文本，無需任何外部執行檔。\n\n• 自動儲存並在啟動時瞬間還原所有譯文。\n• 自動識別免費版與付費版 API Key，智慧調整批次與間隔防止 429 錯誤。\n• 遊戲內快捷鍵：Ctrl+Shift+T（或點擊選單中的「AI 模組翻譯器」）。",
		mod_changes = "純原生遊戲內背景自動翻譯，介面自動跟隨遊戲語言，支援免費/付費配額自動校準。",
		opt_auto_name = "背景自動翻譯模組",
		opt_auto_help = "啟用後，進入遊戲或啟用模組時自動在背景偵測並翻譯未翻譯的模組文本。",
		opt_lang_name = "目標翻譯語言",
		opt_lang_help = "選擇將模組翻譯為哪種目標語言。",
		opt_choice_auto_lang = "自動（跟隨遊戲語言）",
		opt_prov_name = "AI 供應商",
		opt_prov_help = "翻譯使用的 AI 引擎。按 Ctrl+Shift+T 貼上您的 API Key。",
		opt_model_name = "AI 模型",
		opt_model_help = "選擇「自動（使用面板儲存的模型）」或直接指定模型。",
		opt_choice_auto_model = "自動（使用面板儲存的模型）",
		opt_scope_name = "翻譯模組範圍",
		opt_scope_help = "「僅已啟用模組」或「所有已安裝模組」。",
		opt_choice_scope_active = "僅已啟用模組",
		opt_choice_scope_all = "所有已安裝模組",
		opt_quota_name = "自動配額校準（免費 vs 付費 Key）",
		opt_quota_help = "自動偵測免費或付費 API Key，調整批次與間隔避免 429 錯誤。",
		opt_desc_name = "翻譯 MODS 選單中的模組描述",
		opt_desc_help = "將遊戲內模組管理器中的模組標題和描述翻譯為您的語言。",
		opt_hud_name = "顯示右上角背景進度條",
		opt_hud_help = "背景翻譯時於右上角顯示精簡進度提示，完成後自動隱藏。",
		badge_free = "[免費配額]", badge_paid = "[付費配額]", badge_local = "[本機 AI]", badge_invalid = "[金鑰無效]", badge_auto = "[自動]",
		tier_free_fmt = "免費配額 (Free Tier) • 每批: %d • 間隔: %.1f秒",
		tier_paid_fmt = "付費配額 (Paid Tier) • 高速模式 • 每批: %d • 間隔: %.2f秒",
		tier_local_fmt = "本機離線 AI • 無配額限制（每批: %d）",
		tier_invalid = "API Key 無效或遭拒絕",
		tier_missing_key = "尚未設定 API Key（請按 Ctrl+Shift+T）",
		tier_unknown = "等待自動偵測 API 配額",
		provider_no_key_tag = " [免金鑰]",
		btn_ok = "確定", btn_yes = "是", btn_cancel = "取消",
		key_not_set = "未設定", key_set_short = "已設定 (••••)", key_set_masked_fmt = "已設定 (%s••••%s)",
		state_on = "已開啟", state_hidden = "已隱藏", state_active = "已啟用", state_inactive = "未啟用", state_idle = "就緒", state_translating = "翻譯中...",
		status_init = "正在初始化...", status_paused = "已暫停", status_paused_user = "使用者已暫停",
		status_restarting = "正在重新掃描...", status_switching_lang = "正在切換目標語言...", status_clearing_cache = "正在清除快取...",
		hud_paused_detail_fmt = "%s（按 Ctrl+Shift+T 繼續）",
		status_auto_off_fmt = "自動翻譯已關閉（已套用 %d 筆快取譯文）",
		status_scanning = "正在掃描已安裝模組...", hud_scanning_detail = "正在檢查模組文本與原始語言...",
		status_no_mods = "目前沒有其他需要翻譯的模組", hud_no_mods_title = "無待翻譯模組", hud_no_mods_detail = "在模組管理器啟用模組後將自動背景翻譯。",
		status_done_fmt = "100%% 已翻譯（%d 筆文本已生效 · %s）", hud_all_done_title = "模組已 100% 翻譯完成！", hud_all_done_detail_fmt = "已套用 %d 筆譯文（%s）。",
		status_need_key_fmt = "%d 筆待翻譯 • 請按 Ctrl+Shift+T 設定 API Key", hud_need_key_title = "需要設定 API Key", hud_need_key_detail_fmt = "發現 %d 筆新文本！請按 Ctrl+Shift+T 貼上 API Key。",
		status_calibrating = "正在偵測 API 配額（免費 vs 付費）...", hud_calibrating_title = "正在校準 API 配額...", hud_calibrating_detail_fmt = "準備將 %d 筆新文本翻譯為 %s...",
		status_invalid_key = "API Key 無效 • 請按 Ctrl+Shift+T 修改", hud_invalid_key_title = "API Key 無效", hud_invalid_key_detail = "金鑰遭拒絕，請按 Ctrl+Shift+T 更新。",
		status_batch_fmt = "%s：批次 %d/%d (%d%%)", hud_batch_detail_fmt = "%s -> %s • 批次 %d/%d（%d/%d 筆）",
		hud_saved_live_fmt = "即時已儲存！%d/%d 筆已翻譯為 %s",
		hud_paused_quota_title = "翻譯已暫停", hud_finished_title = "翻譯全部完成！", hud_finished_detail_fmt = "所有啟用模組已翻譯為 %s（共儲存 %d 筆）。",
		err_429_daily = "此模型今日免費額度已用盡，請按 Ctrl+Shift+T 切換模型。",
		wait_429_rpm_fmt = "每分鐘限速 (429) • %d 秒後自動繼續...", wait_retry_fmt = "正在重連 AI（第 %d/4 次）...",
		err_invalid_key_http_fmt = "API Key 無效或無權限 (%s)，請按 Ctrl+Shift+T 檢查。",
		panel_title_fmt = "JA3 AI 模組翻譯器 v%s — 背景控制面板 (Ctrl+Shift+T)",
		menu_1_pause_fmt = "1. [暫停] 暫停背景翻譯（%s）",
		menu_1_start = "1. [開始] 立即在背景掃描並翻譯模組",
		menu_2_status_fmt = "2. [狀態] %s | 已快取：%d 筆",
		menu_3_key_fmt = "3. [API KEY] 貼上或修改金鑰（%s）",
		menu_4_prov_fmt = "4. [供應商] AI 引擎：%s",
		menu_5_model_fmt = "5. [模型] AI 模型：%s（從 API 取得清單）",
		menu_6_lang_fmt = "6. [語言] 目標語言：%s -> %s",
		menu_7_quota_fmt = "7. [配額偵測] %s",
		menu_8_mods = "8. [模組報告] 查看已偵測模組、原始語言與進度",
		menu_9_hud_fmt = "9. [HUD 提示] 右上角進度指示器：%s",
		menu_desc_fmt = "10. [模組描述] 翻譯 MODS 選單中的模組描述：%s",
		menu_11_retranslate = "11. [重新翻譯] 重新掃描 / 清除目前語言快取",
		menu_0_close = "0. 關閉面板（翻譯將在背景繼續執行）",
		dlg_status_title = "JA3 AI 模組翻譯器狀態",
		dlg_status_body_fmt = "目前狀態：%s\nAI 供應商：%s\n目前模型：%s\nAPI Key：%s\n配額類型：%s\n目前參數：每批 = %d 筆 | 最小間隔 = %d ms\n實際目標語言：%s (%s)\n磁碟已儲存：%d 筆唯一譯文（%d 個遊戲 ID）",
		dlg_key_title_fmt = "API Key — %s", dlg_key_placeholder = "按 Ctrl+V 在此貼上您的 API Key", dlg_key_desc_fmt = "請按 Ctrl+V 貼上金鑰 (%s)，將儲存於 AppData/JA3TradutorIA。",
		hud_validating_key_title = "正在驗證 API Key...", hud_validating_key_detail = "正在自動識別免費版 / 付費版配額...",
		dlg_key_saved_title = "API Key 已儲存並完成校準", dlg_key_saved_body_fmt = "供應商：%s\n金鑰：%s\n偵測結果：%s\n\n%s",
		dlg_key_saved_ok = "背景自動翻譯即將開始！", dlg_key_saved_check = "請確認金鑰是否貼上正確。",
		dlg_prov_title = "選擇 AI 供應商", dlg_endpoint_title = "OpenAI 相容介面網址", dlg_endpoint_desc = "請輸入基礎 URL（例如 http://localhost:8000/v1）：",
		hud_fetching_models_title = "正在查詢模型...", hud_fetching_models_detail_fmt = "正在從 %s 取得可用模型清單...", dlg_model_title_fmt = "選擇或輸入 AI 模型 (%s)",
		dlg_lang_title = "選擇目標翻譯語言",
		hud_testing_api_title = "正在測試 API...", hud_testing_api_detail = "正在偵測免費 / 付費配額...",
		dlg_quota_title = "API 配額診斷結果", dlg_quota_body_fmt = "供應商：%s\n模型：%s\n診斷：%s\n每批數量：%d 筆\n防 429 間隔：%d ms",
		dlg_mods_title = "已偵測模組與翻譯進度",
		dlg_mods_empty_fmt = "目前範圍（%s）未發現其他可翻譯模組。",
		dlg_mods_header_fmt = "目標語言：%s (%s)\n全域快取：%d 筆唯一譯文 | %d 個已套用 ID\n------------------------------------------------------------",
		dlg_mods_native_lang = "已為目標語言", dlg_mods_item_fmt = "%d. %s [%s]\n   識別語言：%s -> %s",
		hud_enabled_title = "HUD 已開啟", hud_enabled_detail = "背景翻譯時將於右上角顯示進度。",
		dlg_retranslate_title = "重新掃描 / 清除快取", dlg_retranslate_confirm_fmt = "確定要清除「%s」的全部已儲存譯文並從頭重新翻譯嗎？\n\n（點擊「取消」則保留現有譯文，僅掃描新增文本。）",
	},
}

-- Idiomas adicionais da comunidade mapeiam para o pacote mais próximo ou inglês
UI_STRINGS["uk"] = UI_STRINGS["ru"]

-- Retorna o código de idioma da interface atual do jogo ("pt", "en", "es", "fr", "de", "ru", "pl", "id", "zh-CN", "zh-TW")
function M.GetGameUiLang()
	local getLang = rawget(_ENV, "GetLanguage")
	local gameLang = getLang and getLang() or "English"
	return JA3_TO_UI_LANG[gameLang] or "en"
end

-- Traduz uma chave da interface do próprio Mod para o idioma atual do jogo
function M.Tr(key, ...)
	local lang = M.GetGameUiLang()
	local pack = UI_STRINGS[lang] or UI_STRINGS["en"]
	local template = pack[key] or UI_STRINGS["en"][key] or tostring(key)
	if select("#", ...) > 0 then
		local ok, res = pcall(string.format, template, ...)
		if ok then return res end
	end
	return template
end

-- Formata dinamicamente o resumo de cota no idioma atual do jogo
function M.FormatTierSummary(settings)
	local s = settings or (M.LoadSettings and M.LoadSettings()) or {}
	local tier = tostring(s.detectedTier or "unknown")
	local bSize = tonumber(s.batchSize) or 35
	local delayMs = tonumber(s.minDelayMs) or 1500

	if tier == "free" then
		return M.Tr("tier_free_fmt", bSize, delayMs / 1000.0)
	elseif tier == "paid" then
		return M.Tr("tier_paid_fmt", bSize, delayMs / 1000.0)
	elseif tier == "local" then
		return M.Tr("tier_local_fmt", bSize)
	elseif tier == "invalid" then
		return M.Tr("tier_invalid")
	elseif tier == "missing_key" then
		return M.Tr("tier_missing_key")
	end
	return M.Tr("tier_unknown")
end

-- Retorna o rótulo amigável de TargetLanguage / ScanScope / AiModelPreset no idioma atual do jogo
function M.FormatTargetLangSetting(val)
	if not val or val == "" or val == "auto" or val == "Auto (Idioma do Jogo)" or val == "Auto (Game Language)" then
		return M.Tr("opt_choice_auto_lang")
	end
	return tostring(val)
end

function M.IsAutoTargetLang(val)
	return (not val or val == "" or val == "auto"
		or val == "Auto (Idioma do Jogo)"
		or val == "Auto (Game Language)")
end

function M.IsAutoModelPreset(val)
	return (not val or val == "" or val == "auto"
		or val == "Auto (Salvo no Painel)"
		or val == "Auto (Saved in Panel)")
end

function M.IsAllModsScope(val)
	return (val == "all"
		or val == "Todos os Mods Instalados"
		or val == "All Installed Mods")
end

function M.FormatScopeSetting(val)
	if M.IsAllModsScope(val) then
		return M.Tr("opt_choice_scope_all")
	end
	return M.Tr("opt_choice_scope_active")
end

-- Traduz o metadado (nome, tooltip, escolhas) de UMA opção do mod, sem alterar items.lua
function M.LocalizePropMeta(prop)
	local untranslated = rawget(_ENV, "Untranslated")
	if type(prop) ~= "table" or not untranslated then
		return prop
	end
	local keys = {
		AutoTranslate = { "opt_auto_name", "opt_auto_help" },
		TargetLanguage = { "opt_lang_name", "opt_lang_help" },
		AiProvider = { "opt_prov_name", "opt_prov_help" },
		AiModelPreset = { "opt_model_name", "opt_model_help" },
		ScanScope = { "opt_scope_name", "opt_scope_help" },
		TranslateModDescriptions = { "opt_desc_name", "opt_desc_help" },
		AutoTuneQuota = { "opt_quota_name", "opt_quota_help" },
		ShowHudBanner = { "opt_hud_name", "opt_hud_help" },
	}
	local k = keys[prop.id]
	if not k then
		return prop
	end
	prop.name = untranslated(M.Tr(k[1]))
	prop.help = untranslated(M.Tr(k[2]))
	if type(prop.items) == "table" then
		local choiceLabelOverrides = {
			active = M.Tr("opt_choice_scope_active"),
			all    = M.Tr("opt_choice_scope_all"),
		}
		for _, choiceEntry in ipairs(prop.items) do
			if type(choiceEntry) == "table" then
				if choiceEntry.value == "auto" then
					if prop.id == "TargetLanguage" then
						choiceEntry.text = untranslated(M.Tr("opt_choice_auto_lang"))
					elseif prop.id == "AiModelPreset" then
						choiceEntry.text = untranslated(M.Tr("opt_choice_auto_model"))
					end
				elseif choiceLabelOverrides[choiceEntry.value] then
					choiceEntry.text = untranslated(choiceLabelOverrides[choiceEntry.value])
				end
			end
		end
	end
	return prop
end

-- Aplica rótulos traduzidos em uma instância de ModOptionsObject (propriedades já geradas)
function M.LocalizeOptionsObject(optObj)
	if type(optObj) ~= "table" then
		return
	end
	local props = rawget(optObj, "properties")
	if type(props) == "table" then
		for _, prop in ipairs(props) do
			M.LocalizePropMeta(prop)
		end
	end
end

-- Hook de classe: o menu Opções -> Mods chama option:GetOptionMeta() de cada ModItemOption do jogo.
-- Envolvemos esse método (e os das subclasses) para traduzir apenas as opções DESTE mod.
-- Inativo durante Mod Editor / upload para nunca interferir no salvamento.
function M.InstallOptionsHook()
	local classes = rawget(_ENV, "g_Classes")
	if type(classes) ~= "table" then
		return
	end
	local myId = rawget(_ENV, "CurrentModId") or "JA3TradutorIA"
	for _, cls in pairs(classes) do
		if type(cls) == "table" and rawget(cls, "GetOptionMeta") and not rawget(cls, "_ja3TradutorHooked") then
			local orig = rawget(cls, "GetOptionMeta")
			if type(orig) == "function" then
				rawset(cls, "_ja3TradutorHooked", true)
				cls.GetOptionMeta = function(self, ...)
					local meta = orig(self, ...)
					local mod = type(self) == "table" and self.mod
					if type(meta) == "table" and type(mod) == "table" and mod.id == myId then
						local toolsFn = rawget(_ENV, "AreModdingToolsActive")
						local plat = rawget(_ENV, "Platform")
						if not ((toolsFn and toolsFn()) or (type(plat) == "table" and plat.ged)) then
							pcall(M.LocalizePropMeta, meta)
						end
					end
					return meta
				end
			end
		end
	end
end

pcall(M.InstallOptionsHook)

-- Sincroniza título/descrição do ModDef e todas as ModItemOptions do próprio Mod com o idioma atual do jogo,
-- preservando 100% intactos os metadados de publicação na Steam Workshop quando o Mod está descompactado no Mod Editor!
function M.ApplyModUiLocalization()
	local untranslated = rawget(_ENV, "Untranslated")
	local myDef = rawget(_ENV, "CurrentModDef")
	local myId = rawget(_ENV, "CurrentModId") or "JA3TradutorIA"
	if not myDef then
		local modsDict = rawget(_ENV, "Mods")
		myDef = type(modsDict) == "table" and modsDict[myId] or nil
	end

	if type(myDef) == "table" then
		local isPacked = type(myDef.IsPacked) == "function" and myDef:IsPacked()

		-- Quando empacotado (.hpk vindo da Steam Workshop), localiza diretamente ModDef.
		-- Quando descompactado em AppData/Mods (modo autor / Mod Editor), mantém ModDef e items.lua
		-- limpos (IsDirty() == false) para que o Upload para a Steam Workshop nunca sobrescreva metadata.lua!
		if isPacked then
			myDef.title = M.Tr("mod_title")
			myDef.description = M.Tr("mod_desc")
			myDef.last_changes = M.Tr("mod_changes")
		end

		-- Atualiza entrada visual no Gerenciador de Mods do jogo caso esteja aberto
		local modsUi = rawget(_ENV, "g_ModsUIContextObj")
		if type(modsUi) == "table" and type(modsUi.mod_ui_entries) == "table" then
			local uiEntry = modsUi.mod_ui_entries[myId]
			if type(uiEntry) == "table" then
				uiEntry.DisplayName = M.Tr("mod_title")
			end

			-- Se a tradução de descrições dos mods estiver habilitada, atualiza as descrições dos mods traduzidos na UI
			local s = M.LoadSettings()
			if s.translateModDescriptions ~= false and type(M.TranslatedModDescriptions) == "table" then
				local parseHtml = rawget(_ENV, "ParseDescriptionAsHTML")
				for modId, transDesc in pairs(M.TranslatedModDescriptions) do
					if type(transDesc) == "string" and transDesc ~= "" then
						local entry = modsUi.mod_ui_entries[modId]
						if type(entry) == "table" and parseHtml then
							entry.LongDescription = parseHtml(transDesc)
						end
						if type(modsUi.mod_defs) == "table" and modsUi.mod_defs[modId] then
							local targetDef = modsUi.mod_defs[modId]
							if type(targetDef) == "table" then
								local isTargetPacked = type(targetDef.IsPacked) == "function" and targetDef:IsPacked()
								if isTargetPacked then
									targetDef.description = transDesc
								end
							end
						end
					end
				end
			end
		end

		-- Opções do mod: localizadas via hook de classe em ModOptionsObject (ver M.InstallOptionsHook)
		M.InstallOptionsHook()
		if type(myDef.options) == "table" then
			M.LocalizeOptionsObject(myDef.options)
		end
	end

	-- Atualiza também o texto do botão "AI TRANSLATOR" / "TRADUTOR IA" injetado nos XTemplates
	local xTemplates = rawget(_ENV, "XTemplates")
	if type(xTemplates) == "table" and untranslated then
		local btnText = untranslated(M.Tr("menu_button"))
		for _, tplName in ipairs({ "ModManagerActions", "IGMainActions" }) do
			local tpl = xTemplates[tplName]
			local container = type(tpl) == "table" and tpl[1]
			if type(container) == "table" then
				for _, child in ipairs(container) do
					if type(child) == "table" and child.ActionId == "idJA3TradutorIA" then
						child.ActionName = btnText
					end
				end
			end
		end
	end

	-- Atualiza diálogos abertos caso o usuário tenha acabado de trocar o idioma nas Opções do Jogo
	local term = rawget(_ENV, "terminal")
	local desktop = term and term.desktop
	if type(desktop) == "table" and untranslated then
		local btnText = untranslated(M.Tr("menu_button"))
		for _, dlg in ipairs(desktop) do
			if type(dlg) == "table" and type(dlg.actions) == "table" then
				for _, act in ipairs(dlg.actions) do
					if type(act) == "table" and act.ActionId == "idJA3TradutorIA" then
						act.ActionName = btnText
					end
				end
			end
		end
	end
end
