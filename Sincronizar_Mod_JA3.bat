@echo off
chcp 65001 >nul
setlocal

set "SRC_MOD=%~dp0JA3TradutorIA"
set "DST_MOD=%APPDATA%\Jagged Alliance 3\Mods\JA3TradutorIA"

echo ================================================================
echo   JA3 Tradutor IA - Sincronizador para JA3 / Mod Editor (Steam)
echo ================================================================
echo.

if not exist "%SRC_MOD%\metadata.lua" (
    echo [ERRO] Pasta fonte do mod nao encontrada em:
    echo "%SRC_MOD%"
    pause
    exit /b 1
)

if exist "%DST_MOD%" (
    echo Limpando copia anterior do mod em "%DST_MOD%"...
    rmdir /s /q "%DST_MOD%"
)

echo Copiando pacote limpo pronto para Steam Workshop...
xcopy "%SRC_MOD%\*" "%DST_MOD%\" /E /I /Y >nul

echo.
echo [OK] Mod sincronizado com sucesso em:
echo      "%DST_MOD%"
echo.
echo [SEGURANCA] Nenhum dado pessoal, chave de API ou cache foi copiado
echo             para dentro da pasta do Mod.
echo.
echo Agora basta abrir o Jagged Alliance 3 -^> Mod Editor -^> Upload to Steam!
echo (Dica: apos o primeiro upload, pressione Ctrl+S no Mod Editor para salvar o Steam ID).
echo.
pause
