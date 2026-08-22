@echo off
setlocal EnableDelayedExpansion
title Lethal Company Performance Optimizer

REM ============================================================================
REM REPOSITORY CONFIGURATION
REM Set your GitHub username, repository name, and branch below.
REM ============================================================================
set "REPO_USER=hayagerwin"
set "REPO_NAME=lc-mods-patcher"
set "BRANCH=main"

REM Script directory and config path
set "SCRIPT_DIR=%~dp0"
set "CONFIG_DIR=%LOCALAPPDATA%\LCOptimizer"
set "CONFIG_FILE=%CONFIG_DIR%\lc_game_path.txt"

REM Initialize ANSI color codes
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_RESET=%ESC%[0m"

echo %C_CYAN%============================================================================
echo                     Lethal Company Performance Optimizer
echo ============================================================================%C_RESET%
echo.

REM ----------------------------------------------------------------------------
REM 0. SELF-UPDATE CHECK (Always executed FIRST before directory detection)
REM ----------------------------------------------------------------------------
if not defined _LC_OPTIMIZER_SELF_UPDATED (
    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        set "SCRIPT_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/lc_optimizer.bat?t=%RANDOM%"
        set "TEMP_SCRIPT=%TEMP%\lc_optimizer_update_%RANDOM%.bat"
        set "PS_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1?t=%RANDOM%"
        set "TEMP_PS=%TEMP%\lc_optimize_update_%RANDOM%.ps1"

        REM Silently update optimize.ps1 if newer version available
        curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!PS_URL!" -o "!TEMP_PS!" 2>nul
        if exist "!TEMP_PS!" (
            for %%F in ("!TEMP_PS!") do (
                if %%~zF gtr 0 (
                    if exist "%SCRIPT_DIR%optimize.ps1" (
                        fc.exe /b "%SCRIPT_DIR%optimize.ps1" "!TEMP_PS!" >nul 2>nul
                        if errorlevel 1 copy /y "!TEMP_PS!" "%SCRIPT_DIR%optimize.ps1" >nul 2>nul
                    ) else (
                        copy /y "!TEMP_PS!" "%SCRIPT_DIR%optimize.ps1" >nul 2>nul
                    )
                )
            )
            del /f /q "!TEMP_PS!" 2>nul
        )

        REM Self-update lc_optimizer.bat if newer version available
        curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!SCRIPT_URL!" -o "!TEMP_SCRIPT!" 2>nul
        if exist "!TEMP_SCRIPT!" (
            for %%F in ("!TEMP_SCRIPT!") do (
                if %%~zF gtr 0 (
                    fc.exe /b "%~f0" "!TEMP_SCRIPT!" >nul 2>nul
                    if errorlevel 1 (
                        echo %C_CYAN%[UPDATE]%C_RESET% A newer version of lc_optimizer.bat was detected.
                        echo %C_CYAN%[UPDATE]%C_RESET% Updating script and restarting...
                        echo.
                        set "_LC_OPTIMIZER_SELF_UPDATED=1"
                        copy /y "!TEMP_SCRIPT!" "%~f0" >nul & del /f /q "!TEMP_SCRIPT!" 2>nul & call "%~f0" %* & exit /b !errorlevel!
                    )
                )
            )
            del /f /q "!TEMP_SCRIPT!" 2>nul
        )
    )
)

REM ----------------------------------------------------------------------------
REM 1. GAME DIRECTORY DETECTION (Online-Fix, Steam, Custom folders)
REM ----------------------------------------------------------------------------
set "GAME_DIR="

REM Case 1: In-Place Execution (Script is placed directly inside game directory)
if exist "%SCRIPT_DIR%Lethal Company.exe" (
    set "GAME_DIR=%SCRIPT_DIR%"
    goto :game_dir_confirmed
)

REM Case 2: External Execution - Scan for available Lethal Company installations
set "COUNT=0"

REM Scan Saved Location
if exist "%CONFIG_FILE%" (
    set /p SAVED_P=<"%CONFIG_FILE%"
    if defined SAVED_P (
        set "SAVED_P=!SAVED_P:"=!"
        if exist "!SAVED_P!\Lethal Company.exe" (
            set "FOUND_DIR_!SAVED_P!=1"
            set /a COUNT+=1
            for %%K in (!COUNT!) do (
                set "CANDIDATE_%%K=!SAVED_P!"
                set "LABEL_%%K=Previously Used"
            )
        )
    )
)

REM Scan Common Paths
for %%P in (
    "C:\Games\Lethal Company"
    "D:\Games\Lethal Company"
    "E:\Games\Lethal Company"
    "F:\Games\Lethal Company"
    "%ProgramFiles(x86)%\Steam\steamapps\common\Lethal Company"
    "%ProgramFiles%\Steam\steamapps\common\Lethal Company"
    "C:\Program Files\Steam\steamapps\common\Lethal Company"
    "D:\SteamLibrary\steamapps\common\Lethal Company"
    "E:\SteamLibrary\steamapps\common\Lethal Company"
    "F:\SteamLibrary\steamapps\common\Lethal Company"
) do (
    if exist "%%~P\Lethal Company.exe" (
        if not defined FOUND_DIR_%%~P (
            set "FOUND_DIR_%%~P=1"
            set /a COUNT+=1
            for %%K in (!COUNT!) do (
                set "CANDIDATE_%%K=%%~P"
                set "LABEL_%%K=Installed Path"
            )
        )
    )
)

REM Scan Downloads and Desktop
for %%B in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop") do (
    if exist "%%~B\" (
        for /d %%D in ("%%~B\Lethal*") do (
            if exist "%%~fD\Lethal Company.exe" (
                if not defined FOUND_DIR_%%~fD (
                    set "FOUND_DIR_%%~fD=1"
                    set /a COUNT+=1
                    for %%K in (!COUNT!) do (
                        set "CANDIDATE_%%K=%%~fD"
                        set "LABEL_%%K=Found in %%~nB"
                    )
                )
            )
        )
    )
)

REM Present choices if multiple installations found
if !COUNT! gtr 1 (
    echo %C_CYAN%Multiple Lethal Company folders were detected on your PC:%C_RESET%
    echo.
    set "I=1"
    :show_multi_cand
    if !I! leq !COUNT! (
        for %%K in (!I!) do (
            echo   %C_GREEN%[!I!]%C_RESET% !CANDIDATE_%%K!  %C_YELLOW%^(!LABEL_%%K!^)%C_RESET%
        )
        set /a I+=1
        goto :show_multi_cand
    )
    set /a CUSTOM_OPT=!COUNT!+1
    echo   %C_GREEN%[!CUSTOM_OPT!]%C_RESET% Enter / Drag-and-drop a different folder...
    echo.
    :prompt_multi_choice
    set "CHOICE="
    set /p "CHOICE=Select which folder to optimize [1-!CUSTOM_OPT!] (Default: 1): "
    if not defined CHOICE set "CHOICE=1"
    if "!CHOICE!"=="!CUSTOM_OPT!" goto :prompt_custom_path

    set "VALID="
    for %%K in (!CHOICE!) do (
        if defined CANDIDATE_%%K (
            set "GAME_DIR=!CANDIDATE_%%K!"
            set "VALID=1"
        )
    )
    if not defined VALID (
        echo %C_RED%Invalid option. Please enter a number between 1 and !CUSTOM_OPT!.%C_RESET%
        goto :prompt_multi_choice
    )
    goto :game_dir_confirmed
)

REM Single installation found
if !COUNT! equ 1 (
    echo %C_CYAN%Found Lethal Company installation:%C_RESET%
    echo   %C_GREEN%[+]%C_RESET% !CANDIDATE_1! %C_YELLOW%^(!LABEL_1!^)%C_RESET%
    echo.
    echo Press %C_GREEN%[Enter]%C_RESET% to use this folder, or enter/drag-and-drop a different folder:
    set "USER_DIR="
    set /p "USER_DIR=> "
    if defined USER_DIR (
        set "USER_DIR=!USER_DIR:"=!"
        for /f "tokens=* delims= " %%S in ("!USER_DIR!") do set "USER_DIR=%%S"
    )
    if not defined USER_DIR (
        set "GAME_DIR=!CANDIDATE_1!"
        goto :game_dir_confirmed
    )
    set "INPUT_DIR=!USER_DIR!"
    goto :validate_custom_path
)

REM No installations detected - prompt manually
:prompt_custom_path
echo %C_YELLOW%[!] Please specify your Lethal Company game folder.%C_RESET%
echo Enter or drag-and-drop your game folder ^(where "Lethal Company.exe" is located^):
echo.
set /p "INPUT_DIR=> "
if not defined INPUT_DIR goto :err_missing_game

:validate_custom_path
set "INPUT_DIR=!INPUT_DIR:"=!"
if /i "!INPUT_DIR:~-18!"=="Lethal Company.exe" (
    for %%F in ("!INPUT_DIR!") do set "INPUT_DIR=%%~dpF"
)
if "!INPUT_DIR:~-1!"=="\" set "INPUT_DIR=!INPUT_DIR:~0,-1!"

if exist "!INPUT_DIR!\Lethal Company.exe" (
    set "GAME_DIR=!INPUT_DIR!"
) else (
    echo.
    echo %C_RED%[ERROR] "Lethal Company.exe" was not found in: "!INPUT_DIR!"%C_RESET%
    echo.
    goto :prompt_custom_path
)

:game_dir_confirmed
REM Strip trailing backslash from GAME_DIR if present
if "!GAME_DIR:~-1!"=="\" set "GAME_DIR=!GAME_DIR:~0,-1!"

REM Save game path to config
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
echo !GAME_DIR!>"%CONFIG_FILE%" 2>nul

echo %C_GREEN%[+] Selected Game Directory:%C_RESET% !GAME_DIR!
echo.

REM ----------------------------------------------------------------------------
REM 2. SYSTEM UTILITIES CHECK
REM ----------------------------------------------------------------------------
where curl.exe >nul 2>nul
if errorlevel 1 goto :err_missing_curl

where tar.exe >nul 2>nul
if errorlevel 1 goto :err_missing_tar

REM Handle direct command line flags
if /i "%1"=="--optimize" goto :do_optimize_silent
if /i "%1"=="--revert" goto :do_revert_silent

REM ----------------------------------------------------------------------------
REM 3. INTERACTIVE 2-WAY MENU
REM ----------------------------------------------------------------------------
:menu
cls
set "IS_OPTIMIZED=0"
set "LC_CFG=!GAME_DIR!\BepInEx\config\com.github.lethalcompanymodding.LCUltrawide.cfg"
if exist "!LC_CFG!" (
    findstr /i /c:"Gameplay Camera Resolution Multiplier = 0.7" "!LC_CFG!" >nul 2>&1
    if not errorlevel 1 set "IS_OPTIMIZED=1"
)

if "!IS_OPTIMIZED!"=="1" (
    set "STATE_STATUS=%C_GREEN%[ACTIVE] Low-Spec Optimized Mode%C_RESET%"
    set "TAG_OPT=%C_GREEN% [ACTIVE *]%C_RESET%"
    set "TAG_REV="
    set "DEFAULT_OPT=3"
) else (
    set "STATE_STATUS=%C_YELLOW%[ACTIVE] Standard High-Specs (Baseline Default)%C_RESET%"
    set "TAG_OPT="
    set "TAG_REV=%C_YELLOW% [ACTIVE *]%C_RESET%"
    set "DEFAULT_OPT=1"
)

echo %C_CYAN%============================================================================
echo                     Lethal Company Performance Optimizer
echo ============================================================================%C_RESET%
echo   Target Game:   %C_YELLOW%!GAME_DIR!%C_RESET%
echo   Current State: !STATE_STATUS!
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
if not exist "%SCRIPT_DIR%optimize.ps1" (
    curl.exe -s -L -f "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1" -o "%SCRIPT_DIR%optimize.ps1" 2>nul
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%optimize.ps1" -Mode "Check" -GameDir "!GAME_DIR!"
echo %C_CYAN%============================================================================%C_RESET%
echo.
echo   %C_GREEN%[1]%C_RESET% Apply Low-Spec Optimizations  (%C_CYAN%0.7x Res, Shadow/Fog Cuts, Occlusion%C_RESET%)!TAG_OPT!
echo   %C_YELLOW%[2]%C_RESET% Revert to Standard / High Specs (%C_YELLOW%Restore Baseline Friends Copy%C_RESET%)!TAG_REV!
echo   %C_CYAN%[3]%C_RESET% Launch Lethal Company
echo   %C_RED%[Q]%C_RESET% Exit
echo.
set "OPT_CHOICE="
set /p "OPT_CHOICE=Select an option [1, 2, 3, Q] (Default: !DEFAULT_OPT!): "
if not defined OPT_CHOICE set "OPT_CHOICE=!DEFAULT_OPT!"

if "%OPT_CHOICE%"=="1" goto :do_optimize
if "%OPT_CHOICE%"=="2" goto :do_revert
if "%OPT_CHOICE%"=="3" goto :do_launch
if /i "%OPT_CHOICE%"=="q" exit /b 0
if /i "%OPT_CHOICE%"=="exit" exit /b 0
if /i "%OPT_CHOICE%"=="quit" exit /b 0
goto :menu

REM ----------------------------------------------------------------------------
REM 4. STAGE: APPLY OPTIMIZATIONS
REM ----------------------------------------------------------------------------
:do_optimize
echo.
echo %C_CYAN%[1/2]%C_RESET% Synchronizing low-spec plugin DLLs (optimizer_plugins.zip)...
set "PLUGINS_ZIP_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimizer_plugins.zip"
set "TEMP_PLUGINS_ZIP=%TEMP%\lc_opt_plugins_%RANDOM%.zip"

if exist "%SCRIPT_DIR%optimizer_plugins.zip" (
    tar.exe -xf "%SCRIPT_DIR%optimizer_plugins.zip" -C "!GAME_DIR!" 2>nul
    echo   %C_GREEN%[+]%C_RESET% Extracted local optimizer_plugins.zip
) else (
    curl.exe -s -L -f "%PLUGINS_ZIP_URL%" -o "%TEMP_PLUGINS_ZIP%" 2>nul
    if exist "%TEMP_PLUGINS_ZIP%" (
        for %%F in ("%TEMP_PLUGINS_ZIP%") do (
            if %%~zF gtr 0 (
                tar.exe -xf "%TEMP_PLUGINS_ZIP%" -C "!GAME_DIR!" 2>nul
                echo   %C_GREEN%[+]%C_RESET% Downloaded and extracted optimizer_plugins.zip
            )
        )
        del /f /q "%TEMP_PLUGINS_ZIP%" 2>nul
    )
)

echo.
echo %C_CYAN%[2/2]%C_RESET% Applying low-spec configuration tweaks...
if not exist "%SCRIPT_DIR%optimize.ps1" (
    curl.exe -s -L -f "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1" -o "%SCRIPT_DIR%optimize.ps1" 2>nul
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%optimize.ps1" -Mode "Optimize" -GameDir "!GAME_DIR!"

echo.
echo %C_GREEN%============================================================================
echo [SUCCESS] Low-Spec Optimizations have been applied successfully!
echo ============================================================================%C_RESET%
echo.
echo Press any key to return to menu...
pause >nul
goto :menu

:do_optimize_silent
if exist "%SCRIPT_DIR%optimizer_plugins.zip" (
    tar.exe -xf "%SCRIPT_DIR%optimizer_plugins.zip" -C "!GAME_DIR!" 2>nul
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%optimize.ps1" -Mode "Optimize" -GameDir "!GAME_DIR!"
exit /b 0

REM ----------------------------------------------------------------------------
REM 5. STAGE: REVERT OPTIMIZATIONS
REM ----------------------------------------------------------------------------
:do_revert
echo.
echo %C_YELLOW%[1/1]%C_RESET% Reverting configurations back to Standard / High Specs...
if not exist "%SCRIPT_DIR%optimize.ps1" (
    curl.exe -s -L -f "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1" -o "%SCRIPT_DIR%optimize.ps1" 2>nul
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%optimize.ps1" -Mode "Revert" -GameDir "!GAME_DIR!"

echo.
echo %C_YELLOW%============================================================================
echo [SUCCESS] Configurations reverted back to Standard High-Spec defaults!
echo ============================================================================%C_RESET%
echo.
echo Press any key to return to menu...
pause >nul
goto :menu

:do_revert_silent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%optimize.ps1" -Mode "Revert" -GameDir "!GAME_DIR!"
exit /b 0

REM ----------------------------------------------------------------------------
REM 6. LAUNCH GAME & SELF-UPDATE
REM ----------------------------------------------------------------------------
:do_launch
echo.
echo %C_CYAN%Launching Lethal Company...%C_RESET%
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
timeout /t 1 >nul 2>&1
exit



REM ============================================================================
REM ERROR HANDLERS (Identical to lethal_company_patcher.bat)
REM ============================================================================
:err_missing_game
echo %C_RED%[ERROR] "Lethal Company.exe" was not found.%C_RESET%
echo.
echo Please make sure you have Lethal Company installed (Steam, Online-Fix, or custom repack),
echo and place this script inside your game folder or provide the correct path when prompted.
echo.
pause
exit /b 1

:err_missing_curl
echo %C_RED%[ERROR] "curl.exe" was not found on your system.%C_RESET%
echo Windows 10 (version 1803+) or Windows 11 is required for native sync.
echo.
pause
exit /b 1

:err_missing_tar
echo %C_RED%[ERROR] "tar.exe" was not found on your system.%C_RESET%
echo Windows 10 (version 1803+) or Windows 11 is required for native sync.
echo.
pause
exit /b 1
