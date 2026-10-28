# JA3 Tradutor IA — Mod Nativo para Jagged Alliance 3

Auto-tradutor de mods **100% nativo em segundo plano dentro do próprio jogo**, sem nenhum executável externo.

* **Steam Workshop oficial:** [JA3 AI Translator / Tradutor IA (ID: 3828475103)](https://steamcommunity.com/sharedfiles/filedetails/?id=3828475103)

## Estrutura do Repositório

```text
JA3Tradutor/
├── JA3TradutorIA/                              <-- PACOTE PURO DO MOD (ModContent.hpk)
│   ├── metadata.lua                            <-- Metadados oficiais, Tags JA3 e Preview.png
│   ├── items.lua                               <-- Opções nativas (ModItemOption) + ModItemCode
│   ├── Preview.png                             <-- Capa 16:9 (< 1 MB) para Steam Workshop e Mod Manager
│   └── Code/
│       ├── 01_EngineBridge.lua                 <-- Ponte segura com LuaModEnv + Codec JSON em Lua
│       ├── 01b_UiLocalization.lua              <-- UI do Mod sincronizada em tempo real com o idioma do JA3
│       ├── 02_TagProtector.lua                 <-- Proteção e restauração de tags táticas (<color>, <image>, etc.)
│       ├── 03_StorageAndCache.lua              <-- Cache persistente em AppData/JA3TradutorIA e injeção em memória
│       ├── 04_ModStringScanner.lua             <-- Scanner de mods ativos/instalados + detecção de idioma original
│       ├── 05_AiClient.lua                     <-- Cliente HTTPS multi-IA + detecção de cota Gratuita vs. Paga
│       ├── 06_HudAndMenu.lua                   <-- Indicador sutil no HUD + Painel interativo (Ctrl+Shift+T)
│       └── 07_AutoTranslator.lua               <-- Worker assíncrono em segundo plano e ciclo de vida no motor
├── SteamWorkshop/                              <-- Materiais auxiliares de publicação na Steam Workshop
│   ├── Banner_Workshop_HD.jpg                  <-- Arte HD opcional para Screenshots (1376x768)
│   ├── DESCRICAO_WORKSHOP_PTBR.bbcode.txt      <-- Descrição BBCode em Português (Brasil)
│   ├── DESCRIPTION_WORKSHOP_EN.bbcode.txt      <-- Descrição BBCode em Inglês
│   └── GUIA_PUBLICACAO_STEAM_WORKSHOP.md       <-- Passo a passo completo de publicação
└── Sincronizar_Mod_JA3.bat                     <-- Sincroniza JA3TradutorIA/ para %APPDATA%\Jagged Alliance 3\Mods\
```

## Como Usar Dentro do Jogo

1. Ative **JA3 AI Translator / Tradutor IA** no **Gerenciador de Mods** do *Jagged Alliance 3*.
2. Pressione **`Ctrl + Shift + T`** a qualquer momento dentro do jogo (ou clique no botão **TRADUTOR IA** no Gerenciador de Mods ou no Menu de Pausa) para configurar provedor, chave de API, modelo ou idioma destino.
3. Todas as traduções e configurações ficam salvas automaticamente em `%APPDATA%\Jagged Alliance 3\JA3TradutorIA\` (completamente isoladas da pasta empacotada do Mod).

## Publicação na Steam Workshop

Siga o passo a passo em [`SteamWorkshop/GUIA_PUBLICACAO_STEAM_WORKSHOP.md`](./SteamWorkshop/GUIA_PUBLICACAO_STEAM_WORKSHOP.md).
