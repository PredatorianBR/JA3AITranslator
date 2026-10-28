# Guia de Publicação na Steam Workshop — JA3 Tradutor IA

* **Link oficial publicado:** [https://steamcommunity.com/sharedfiles/filedetails/?id=3828475103](https://steamcommunity.com/sharedfiles/filedetails/?id=3828475103)
* **Steam Workshop ID:** `3828475103`

O pacote do mod em [`../JA3TradutorIA/`](../JA3TradutorIA) (já sincronizado em `%APPDATA%\Jagged Alliance 3\Mods\JA3TradutorIA\`) está 100% limpo, validado e com o `steam_id = 3828475103` devidamente registrado.

---

## 1. Arquivos do Pacote do Mod (`JA3TradutorIA/`)

| Arquivo | Função |
| :--- | :--- |
| [`metadata.lua`](../JA3TradutorIA/metadata.lua) | Metadados oficiais (`ModDef`), tags (`Localization`, `UI`, `Libs & Modding Tools`, `Game Settings`), `Preview.png`, `last_changes` e lista `ignore_files` blindada |
| [`items.lua`](../JA3TradutorIA/items.lua) | Opções nativas do menu *Opções -> Mods* (`ModItemOption*`) + registro dos 8 módulos Lua (`ModItemCode`) |
| [`Preview.png`](../JA3TradutorIA/Preview.png) | Miniatura oficial `16:9` (`800x450`, `~729 KB`, abaixo do limite de `1 MB` da Steam) com zona segura central `1:1` |
| [`Code/01_EngineBridge.lua`](../JA3TradutorIA/Code/01_EngineBridge.lua) | Ponte segura com `LuaModEnv` e codec JSON puro em Lua |
| [`Code/01b_UiLocalization.lua`](../JA3TradutorIA/Code/01b_UiLocalization.lua) | Localização dinâmica da UI do mod nos 10 idiomas oficiais do JA3 |
| [`Code/02_TagProtector.lua`](../JA3TradutorIA/Code/02_TagProtector.lua) | Proteção e restauração de tags táticas (`<color>`, `<image>`, placeholders, variáveis) |
| [`Code/03_StorageAndCache.lua`](../JA3TradutorIA/Code/03_StorageAndCache.lua) | Persistência em `AppData/JA3TradutorIA/` (fora da pasta do mod) e injeção em `TranslationTable` |
| [`Code/04_ModStringScanner.lua`](../JA3TradutorIA/Code/04_ModStringScanner.lua) | Scanner de mods instalados/ativos e detector automático do idioma de origem |
| [`Code/05_AiClient.lua`](../JA3TradutorIA/Code/05_AiClient.lua) | Cliente HTTP assíncrono multi-provedor + calibração automática de cota Gratuita vs. Paga |
| [`Code/06_HudAndMenu.lua`](../JA3TradutorIA/Code/06_HudAndMenu.lua) | Barra de progresso sutil no HUD + painel interativo (`Ctrl+Shift+T`) |
| [`Code/07_AutoTranslator.lua`](../JA3TradutorIA/Code/07_AutoTranslator.lua) | Worker em segundo plano (`CreateRealTimeThread`) e hooks de ciclo de vida do motor |

---

## 2. Passo a Passo para Publicar na Steam Workshop (1 Minuto)

1. Caso altere algum arquivo em `JA3TradutorIA/`, execute [`../Sincronizar_Mod_JA3.bat`](../Sincronizar_Mod_JA3.bat) para atualizar `%APPDATA%\Jagged Alliance 3\Mods\JA3TradutorIA\`.
2. Abra a **Steam** e inicie o **Jagged Alliance 3**.
3. No Menu Principal, clique em **Gerenciador de Mods (Mod Manager)** -> **Editor de Mods (Mod Editor)**.
4. Na janela do **Mod Manager (Ged)**, dê duplo clique em **`JA3 AI Translator / Tradutor IA`** (`id JA3TradutorIA`).
5. Na janela **Mod Editor**:
   - Confira que **Title**, **Description**, **Preview image (`Preview.png`)**, **Last changes** e **Tags** já estão preenchidos.
   - *(Opcional)* Aponte `Screenshot 1` para [`Banner_Workshop_HD.jpg`](./Banner_Workshop_HD.jpg) ou capturas de tela dentro do jogo.
   - Clique em **Upload to Steam** na barra superior e confirme em **OK**.
6. Aguarde a confirmação **`Mod JA3 AI Translator / Tradutor IA was successfully uploaded!`**.
7. **Importante (após o 1º upload):** Pressione **`Ctrl + S`** no Mod Editor para gravar o `steam_id` gerado no `metadata.lua` (assim futuras atualizações atualizarão o mesmo item na Steam Workshop).
8. Na página do item na Steam Workshop, cole opcionalmente [`DESCRIPTION_WORKSHOP_EN.bbcode.txt`](./DESCRIPTION_WORKSHOP_EN.bbcode.txt) (aba **English**) e [`DESCRICAO_WORKSHOP_PTBR.bbcode.txt`](./DESCRICAO_WORKSHOP_PTBR.bbcode.txt) (aba **Português - Brasil**) e defina a visibilidade como **Público**.
