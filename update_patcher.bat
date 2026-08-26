@echo off
setlocal EnableDelayedExpansion
title Lethal Company Patcher - Quick Updater & Cache Reset

echo ============================================================================
echo           Lethal Company Mod Patcher - Fast Update & Cache Reset
echo ============================================================================
echo.

set "REPO_USER=hayagerwin"
set "REPO_NAME=lc-mods-patcher"
set "BRANCH=main"

echo [*] Downloading latest lethal_company_patcher.bat from GitHub...
set "DEST_DIR=%~dp0"
if exist "%DEST_DIR%lethal_company_patcher.bat" (
    set "DEST=%DEST_DIR%lethal_company_patcher.bat"
) else (
    set "DEST=%USERPROFILE%\Desktop\lethal_company_patcher.bat"
)

set "URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/lethal_company_patcher.bat?t=%RANDOM%%RANDOM%"

powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { (New-Object Net.WebClient).DownloadFile('%URL%', '%DEST%'); Write-Output 'SUCCESS' } catch { Write-Output 'FAILED' }" > "%TEMP%\lc_upd_status.txt"

set /p STATUS=<"%TEMP%\lc_upd_status.txt"
del /f /q "%TEMP%\lc_upd_status.txt" 2>nul

if "%STATUS%"=="SUCCESS" (
    echo.
    echo [OK] Successfully updated: %DEST%
    echo [*] Launching updated patcher...
    echo.
    timeout /t 1 /nobreak >nul
    start "" "%DEST%"
) else (
    echo.
    echo [ERROR] Could not download patcher. Trying fallback curl...
    curl.exe -s -L -f -H "Cache-Control: no-cache" "%URL%" -o "%DEST%"
    if exist "%DEST%" (
        echo [OK] Successfully downloaded via curl!
        start "" "%DEST%"
    ) else (
        echo [!] Failed to update patcher. Please check internet connection.
        pause
    )
)
exit /b 0
