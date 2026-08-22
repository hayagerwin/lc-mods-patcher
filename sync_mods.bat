@echo off
setlocal EnableDelayedExpansion
title Lethal Company Mod Patcher - Migration

REM ============================================================================
REM REPOSITORY CONFIGURATION
REM ============================================================================
set "REPO_USER=hayagerwin"
set "REPO_NAME=lc-mods-patcher"
set "BRANCH=main"

cd /d "%~dp0"

REM Initialize ANSI color codes
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_RESET=%ESC%[0m"

echo %C_CYAN%============================================================================
echo               Lethal Company Mod Patcher - Migration Helper
echo ============================================================================%C_RESET%
echo.
echo %C_YELLOW%[*] "sync_mods.bat" has been renamed to "lethal_company_patcher.bat".%C_RESET%
echo %C_CYAN%[*] Downloading the updated "lethal_company_patcher.bat"...%C_RESET%
echo.

set "NEW_SCRIPT=%~dp0lethal_company_patcher.bat"
set "PATCHER_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/lethal_company_patcher.bat?t=%RANDOM%"

where curl.exe >nul 2>nul
if errorlevel 1 (
    echo %C_RED%[ERROR] curl.exe was not found. Please download lethal_company_patcher.bat manually.%C_RESET%
    pause
    exit /b 1
)

curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "%PATCHER_URL%" -o "%NEW_SCRIPT%"

if exist "%NEW_SCRIPT%" (
    echo %C_GREEN%[+] Migration successful! Launching lethal_company_patcher.bat...%C_RESET%
    echo.
    start "" "%NEW_SCRIPT%" %*
    exit /b 0
) else (
    echo %C_RED%[ERROR] Failed to download lethal_company_patcher.bat from GitHub.%C_RESET%
    echo Please check your internet connection or download it directly from GitHub.
    echo.
    pause
    exit /b 1
)
