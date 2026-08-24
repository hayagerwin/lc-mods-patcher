@echo off
setlocal EnableDelayedExpansion
title Lethal Company Mod Patcher

REM ============================================================================
REM REPOSITORY CONFIGURATION
REM Set your GitHub username, repository name, and branch below.
REM ============================================================================
set "REPO_USER=hayagerwin"
set "REPO_NAME=lc-mods-patcher"
set "BRANCH=main"
set "PATCHER_VERSION=2026082402"

REM Script directory and config path
set "SCRIPT_DIR=%~dp0"
set "CONFIG_DIR=%LOCALAPPDATA%\LCModsPatcher"
set "CONFIG_FILE=%CONFIG_DIR%\lc_game_path.txt"

REM Initialize ANSI color codes
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_RESET=%ESC%[0m"

echo %C_CYAN%============================================================================
echo                        Lethal Company Mod Patcher
echo ============================================================================%C_RESET%
echo.

REM ----------------------------------------------------------------------------
REM 0. SELF-UPDATE CHECK (Always executed FIRST before directory detection)
REM ----------------------------------------------------------------------------
if not defined _LC_PATCHER_SELF_UPDATED (
    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        set "SCRIPT_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/lethal_company_patcher.bat"
        set "TEMP_SCRIPT=%TEMP%\lc_patcher_update_%RANDOM%.bat"

        curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!SCRIPT_URL!" -o "!TEMP_SCRIPT!" 2>nul
        if exist "!TEMP_SCRIPT!" (
            set "REMOTE_VERSION="
            for /f "tokens=2 delims==" %%V in ('findstr /i "PATCHER_VERSION" "!TEMP_SCRIPT!"') do (
                set "RAW_REMOTE=%%V"
                set "RAW_REMOTE=!RAW_REMOTE:"=!"
                set "RAW_REMOTE=!RAW_REMOTE: =!"
                set "REMOTE_VERSION=!RAW_REMOTE!"
            )
            if defined REMOTE_VERSION (
                if !REMOTE_VERSION! gtr !PATCHER_VERSION! (
                    echo %C_CYAN%[UPDATE]%C_RESET% A newer version of lethal_company_patcher.bat was detected.
                    echo %C_CYAN%[UPDATE]%C_RESET% Updating script from build !PATCHER_VERSION! -^> !REMOTE_VERSION!...
                    echo.
                    set "_LC_PATCHER_SELF_UPDATED=1"
                    copy /y "!TEMP_SCRIPT!" "%~f0" >nul & del /f /q "!TEMP_SCRIPT!" 2>nul & call "%~f0" %* & exit /b !errorlevel!
                )
            )
            del /f /q "!TEMP_SCRIPT!" 2>nul
        )
    )
)

REM Cleanup legacy migration scripts if present (for players outside git repo)
if not exist "%SCRIPT_DIR%.git" (
    if exist "%SCRIPT_DIR%sync_mods.bat" del /f /q "%SCRIPT_DIR%sync_mods.bat" 2>nul
    if exist "%SCRIPT_DIR%sync_mods.py" del /f /q "%SCRIPT_DIR%sync_mods.py" 2>nul
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
                set "LABEL_%%K=Saved Location"
            )
        )
    )
)

REM Scan MRU / OpenSavePidlMRU in registry
for /f "tokens=3*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU" /s 2^>nul ^| findstr /i "Lethal"') do (
    set "REG_PATH=%%A %%B"
    set "REG_PATH=!REG_PATH:~0,-1!"
    if exist "!REG_PATH!\Lethal Company.exe" (
        if not defined FOUND_DIR_!REG_PATH! (
            set "FOUND_DIR_!REG_PATH!=1"
            set /a COUNT+=1
            for %%K in (!COUNT!) do (
                set "CANDIDATE_%%K=!REG_PATH!"
                set "LABEL_%%K=Recently Used"
            )
        )
    )
)

REM Scan Windows Recent Shortcuts
if exist "%APPDATA%\Microsoft\Windows\Recent" (
    for %%F in ("%APPDATA%\Microsoft\Windows\Recent\*Lethal*.lnk") do (
        for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%%~fF').TargetPath; if(Test-Path $s){$s}" 2^>nul`) do (
            set "LNK_TARGET=%%~dpT"
            if defined LNK_TARGET if "!LNK_TARGET:~-1!"=="\" set "LNK_TARGET=!LNK_TARGET:~0,-1!"
            if exist "!LNK_TARGET!\Lethal Company.exe" (
                if not defined FOUND_DIR_!LNK_TARGET! (
                    set "FOUND_DIR_!LNK_TARGET!=1"
                    set /a COUNT+=1
                    for %%K in (!COUNT!) do (
                        set "CANDIDATE_%%K=!LNK_TARGET!"
                        set "LABEL_%%K=Recent Shortcut"
                    )
                )
            )
        )
    )
)

REM Scan LocalAppData and AppData
for %%P in ("%LOCALAPPDATA%\Programs\Lethal Company" "%APPDATA%\Lethal Company") do (
    if exist "%%~P\Lethal Company.exe" (
        if not defined FOUND_DIR_%%~P (
            set "FOUND_DIR_%%~P=1"
            set /a COUNT+=1
            for %%K in (!COUNT!) do (
                set "CANDIDATE_%%K=%%~P"
                set "LABEL_%%K=AppData Install"
            )
        )
    )
)

REM Scan 7-Zip & WinRAR History in Registry
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\7-Zip\FM" /v "History" 2^>nul ^| findstr /i "History"') do (
    set "RAW_HIST=%%B"
    for %%S in (!RAW_HIST!) do (
        if exist "%%~fS\Lethal Company.exe" (
            if not defined FOUND_DIR_%%~fS (
                set "FOUND_DIR_%%~fS=1"
                set /a COUNT+=1
                for %%K in (!COUNT!) do (
                    set "CANDIDATE_%%K=%%~fS"
                    set "LABEL_%%K=Previously Used"
                )
            )
        )
        for /d %%T in ("%%~fS\*") do (
            if exist "%%~fT\Lethal Company.exe" (
                if not defined FOUND_DIR_%%~fT (
                    set "FOUND_DIR_%%~fT=1"
                    set /a COUNT+=1
                    for %%K in (!COUNT!) do (
                        set "CANDIDATE_%%K=%%~fT"
                        set "LABEL_%%K=Previously Used"
                    )
                )
            )
        )
    )
)

REM Scan Common Paths and Drives
for %%V in (C D E F G H) do (
    if exist "%%V:\" (
        for %%P in (
            "%%V:\Games\Lethal Company"
            "%%V:\SteamLibrary\steamapps\common\Lethal Company"
            "%%V:\Steam\steamapps\common\Lethal Company"
            "%%V:\Program Files (x86)\Steam\steamapps\common\Lethal Company"
            "%%V:\Program Files\Steam\steamapps\common\Lethal Company"
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
        if exist "%%V:\Games\" (
            for /d %%D in ("%%V:\Games\*Lethal*" "%%V:\Games\Lethal*") do (
                if exist "%%~fD\Lethal Company.exe" (
                    if not defined FOUND_DIR_%%~fD (
                        set "FOUND_DIR_%%~fD=1"
                        set /a COUNT+=1
                        for %%K in (!COUNT!) do (
                            set "CANDIDATE_%%K=%%~fD"
                            set "LABEL_%%K=Found on %%V:\Games"
                        )
                    )
                )
                for /d %%S in ("%%~fD\*") do (
                    if exist "%%~fS\Lethal Company.exe" (
                        if not defined FOUND_DIR_%%~fS (
                            set "FOUND_DIR_%%~fS=1"
                            set /a COUNT+=1
                            for %%K in (!COUNT!) do (
                                set "CANDIDATE_%%K=%%~fS"
                                set "LABEL_%%K=Found on %%V:\Games"
                            )
                        )
                    )
                )
            )
        )
    )
)

REM Scan User Directories (Downloads, Desktop, Documents)
for %%B in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%USERPROFILE%\Documents") do (
    if exist "%%~B\" (
        for /d %%D in ("%%~B\*Lethal*" "%%~B\Lethal*") do (
            REM Direct check
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
            REM Subfolder depth 1 check
            for /d %%S in ("%%~fD\*") do (
                if exist "%%~fS\Lethal Company.exe" (
                    if not defined FOUND_DIR_%%~fS (
                        set "FOUND_DIR_%%~fS=1"
                        set /a COUNT+=1
                        for %%K in (!COUNT!) do (
                            set "CANDIDATE_%%K=%%~fS"
                            set "LABEL_%%K=Found in %%~nB"
                        )
                    )
                )
                REM Subfolder depth 2 check
                for /d %%T in ("%%~fS\*") do (
                    if exist "%%~fT\Lethal Company.exe" (
                        if not defined FOUND_DIR_%%~fT (
                            set "FOUND_DIR_%%~fT=1"
                            set /a COUNT+=1
                            for %%K in (!COUNT!) do (
                                set "CANDIDATE_%%K=%%~fT"
                                set "LABEL_%%K=Found in %%~nB"
                            )
                        )
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
    echo   %C_GREEN%[!CUSTOM_OPT!]%C_RESET% Enter / Drag-and-drop / Browse for a different folder...
    echo.
    :prompt_multi_choice
    set "CHOICE="
    set /p "CHOICE=Select which folder to use [1-!CUSTOM_OPT!] (Default: 1): "
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
    set "GAME_DIR=!CANDIDATE_1!"
    goto :game_dir_confirmed
)

REM No installations detected - prompt manually
:prompt_custom_path
echo.
echo %C_YELLOW%[!] Please specify your Lethal Company game folder.%C_RESET%
echo   Option 1: Drag-and-drop your game folder or "Lethal Company.exe" here
echo   Option 2: Type %C_CYAN%B%C_RESET% and press Enter to browse with Windows folder picker
echo   Option 3: Type the full folder path and press Enter
echo.
set "INPUT_DIR="
set /p "INPUT_DIR=> "
if not defined INPUT_DIR goto :err_missing_game

REM Check if user requested GUI browser
if /i "!INPUT_DIR!"=="B" goto :prompt_browse_path
if /i "!INPUT_DIR!"=="BROWSE" goto :prompt_browse_path
goto :validate_custom_path

:prompt_browse_path
echo.
echo   %C_CYAN%-^> Opening Windows folder browser...%C_RESET%
set "INPUT_DIR="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Select your Lethal Company game folder'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$f.SelectedPath}"`) do set "INPUT_DIR=%%D"
if not defined INPUT_DIR (
    echo   Folder selection cancelled.
    goto :prompt_custom_path
)
goto :validate_custom_path

:validate_custom_path
if defined INPUT_DIR (
    set "INPUT_DIR=!INPUT_DIR:"=!"
    for /f "tokens=* delims= " %%S in ("!INPUT_DIR!") do set "INPUT_DIR=%%S"
    if defined INPUT_DIR (
        if "!INPUT_DIR:~-1!"=="\" set "INPUT_DIR=!INPUT_DIR:~0,-1!"
    )
)

if not defined INPUT_DIR goto :prompt_custom_path

REM 1. Check direct folder
if exist "!INPUT_DIR!\Lethal Company.exe" (
    set "GAME_DIR=!INPUT_DIR!"
    goto :game_dir_confirmed
)

REM 2. Check subfolder depth 1
for /d %%S in ("!INPUT_DIR!\*") do (
    if exist "%%~fS\Lethal Company.exe" (
        set "GAME_DIR=%%~fS"
        goto :game_dir_confirmed
    )
)

REM 3. Check subfolder depth 2
for /d %%S in ("!INPUT_DIR!\*") do (
    for /d %%T in ("%%~fS\*") do (
        if exist "%%~fT\Lethal Company.exe" (
            set "GAME_DIR=%%~fT"
            goto :game_dir_confirmed
        )
    )
)

REM 4. Check parent directories
if exist "!INPUT_DIR!\..\Lethal Company.exe" (
    for %%F in ("!INPUT_DIR!\..") do set "GAME_DIR=%%~fF"
    goto :game_dir_confirmed
)
if exist "!INPUT_DIR!\..\..\Lethal Company.exe" (
    for %%F in ("!INPUT_DIR!\..\..") do set "GAME_DIR=%%~fF"
    goto :game_dir_confirmed
)

echo.
echo %C_RED%[ERROR] "Lethal Company.exe" was not found in: "!INPUT_DIR!" or its subfolders.%C_RESET%
echo.
goto :prompt_custom_path

:game_dir_confirmed
REM Strip trailing backslash from GAME_DIR if present
if "!GAME_DIR:~-1!"=="\" set "GAME_DIR=!GAME_DIR:~0,-1!"

REM Save game path to config
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
echo !GAME_DIR!>"%CONFIG_FILE%" 2>nul

:main_menu
cls
echo %C_CYAN%============================================================================
echo                     Lethal Company Mod Patcher & Toolset
echo ============================================================================%C_RESET%
echo.
echo %C_GREEN%[+] Target Game Directory:%C_RESET% !GAME_DIR!
echo.
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo   Select an action:
echo     %C_GREEN%[ENTER]%C_RESET% -^> %C_GREEN%Update ^& Apply Latest Mods%C_RESET% ^(Default / Recommended^)
echo     %C_YELLOW%[1]%C_RESET%     -^> %C_YELLOW%Performance ^& Low-Spec Optimizer Tool%C_RESET%
echo     %C_CYAN%[C]%C_RESET%     -^> %C_CYAN%Change / Browse Game Directory%C_RESET%
echo     %C_RED%[Q]%C_RESET%     -^> %C_RED%Exit%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo.
set "USER_ACTION="
set /p "USER_ACTION=Enter choice (Default: [ENTER] to Update): "
if defined USER_ACTION (
    set "USER_ACTION=!USER_ACTION:"=!"
    for /f "tokens=* delims= " %%S in ("!USER_ACTION!") do set "USER_ACTION=%%S"
)
if not defined USER_ACTION goto :run_patcher_flow
if /i "!USER_ACTION!"=="U" goto :run_patcher_flow
if /i "!USER_ACTION!"=="UPDATE" goto :run_patcher_flow
if /i "!USER_ACTION!"=="P" goto :run_patcher_flow
if /i "!USER_ACTION!"=="PATCH" goto :run_patcher_flow
if /i "!USER_ACTION!"=="Y" goto :run_patcher_flow
if /i "!USER_ACTION!"=="YES" goto :run_patcher_flow
if "!USER_ACTION!"=="1" goto :optimizer_menu
if /i "!USER_ACTION!"=="OPT" goto :optimizer_menu
if /i "!USER_ACTION!"=="OPTIMIZE" goto :optimizer_menu
if /i "!USER_ACTION!"=="C" goto :prompt_custom_path
if /i "!USER_ACTION!"=="CHANGE" goto :prompt_custom_path
if /i "!USER_ACTION!"=="Q" exit /b 0
if /i "!USER_ACTION!"=="QUIT" exit /b 0
if /i "!USER_ACTION!"=="EXIT" exit /b 0
if "!USER_ACTION!"=="0" exit /b 0

REM If user typed anything else unrecognized, assume patcher flow
goto :run_patcher_flow


REM ============================================================================
REM FLOW 1: PERFORMANCE OPTIMIZER SUBMENU (WITH LIVE CHECKLIST)
REM ============================================================================
:optimizer_menu
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

set "PS_SCRIPT=%SCRIPT_DIR%optimizer\optimize.ps1"
set "PS_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1?t=%RANDOM%"
set "OPT_ZIP_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimizer_plugins.zip?t=%RANDOM%"
set "TEMP_PS=%TEMP%\lc_optimize_%RANDOM%.ps1"
set "TEMP_OPT_ZIP=%TEMP%\lc_opt_plugins_%RANDOM%.zip"

if not exist "!PS_SCRIPT!" (
    curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!PS_URL!" -o "!TEMP_PS!" 2>nul
    if exist "!TEMP_PS!" set "PS_SCRIPT=!TEMP_PS!"
)

if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "Check" -GameDir "!GAME_DIR!"
)
echo %C_CYAN%============================================================================%C_RESET%
echo.
echo   %C_GREEN%[1]%C_RESET% Apply Low-Spec Optimizations  (%C_CYAN%0.7x Res, Shadow/Fog Cuts, Occlusion%C_RESET%)!TAG_OPT!
echo   %C_YELLOW%[2]%C_RESET% Revert to Standard / High Specs (%C_YELLOW%Restore Baseline Friends Copy%C_RESET%)!TAG_REV!
echo   %C_CYAN%[3]%C_RESET% Launch Lethal Company
echo   %C_CYAN%[B]%C_RESET% Back to Main Menu
echo   %C_RED%[Q]%C_RESET% Exit
echo.
set "OPT_CHOICE="
set /p "OPT_CHOICE=Select an option [1, 2, 3, B, Q] (Default: !DEFAULT_OPT!): "
if not defined OPT_CHOICE set "OPT_CHOICE=!DEFAULT_OPT!"

if "%OPT_CHOICE%"=="1" goto :do_apply_optimizer
if "%OPT_CHOICE%"=="2" goto :do_revert_optimizer
if "%OPT_CHOICE%"=="3" goto :do_launch_from_optimizer
if /i "%OPT_CHOICE%"=="B" goto :main_menu
if /i "%OPT_CHOICE%"=="BACK" goto :main_menu
if /i "%OPT_CHOICE%"=="Q" exit /b 0
if /i "%OPT_CHOICE%"=="QUIT" exit /b 0
if "%OPT_CHOICE%"=="0" exit /b 0
goto :optimizer_menu

:do_apply_optimizer
echo.
echo %C_CYAN%[1/2] Applying Low-Spec Performance Optimizations...%C_RESET%
if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "Optimize" -GameDir "!GAME_DIR!"
)
echo.
echo %C_CYAN%[2/2] Synchronizing FPS Counter overlay plugin...%C_RESET%
curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!OPT_ZIP_URL!" -o "!TEMP_OPT_ZIP!" 2>nul
if exist "!TEMP_OPT_ZIP!" (
    tar.exe -xf "!TEMP_OPT_ZIP!" -C "!GAME_DIR!" 2>nul
    del /f /q "!TEMP_OPT_ZIP!" 2>nul
)
if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
echo.
echo %C_GREEN%[SUCCESS] Low-Spec Optimizations Applied!%C_RESET%
echo.
pause
goto :optimizer_menu

:do_revert_optimizer
echo.
echo %C_YELLOW%Reverting to Standard / High Specs...%C_RESET%
if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "Revert" -GameDir "!GAME_DIR!"
)
if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
echo.
echo %C_GREEN%[SUCCESS] Reverted to Standard Default Graphics.%C_RESET%
echo.
pause
goto :optimizer_menu

:do_launch_from_optimizer
echo.
echo %C_CYAN%Launching Lethal Company...%C_RESET%
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
timeout /t 1 >nul 2>&1
exit


REM ============================================================================
REM FLOW 2: MOD PATCHER & UPDATE (DEFAULT ENTRY)
REM ============================================================================
:run_patcher_flow
cls
echo %C_CYAN%============================================================================
echo                        Lethal Company Mod Patcher
echo ============================================================================%C_RESET%
echo.
echo %C_GREEN%[+] Selected Game Directory:%C_RESET% !GAME_DIR!
echo.

REM ----------------------------------------------------------------------------
REM 2. SYSTEM UTILITIES CHECK
REM ----------------------------------------------------------------------------
where curl.exe >nul 2>nul
if errorlevel 1 (
    goto :err_missing_curl
)

where tar.exe >nul 2>nul
if errorlevel 1 (
    goto :err_missing_tar
)

REM Switch working directory to game folder
cd /d "!GAME_DIR!"

REM Setup remote URLs and temporary paths
set "DELETE_LIST_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/delete_list.txt"
set "PATCH_ZIP_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/patch.zip"
set "PATCH_INFO_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/patch_info.txt"
set "TEMP_DELETE_LIST=%TEMP%\lc_delete_list_%RANDOM%.txt"
set "TEMP_PATCH_ZIP=%TEMP%\lc_patch_%RANDOM%.zip"
set "TEMP_PATCH_INFO=%TEMP%\lc_patch_info_%RANDOM%.txt"

REM ----------------------------------------------------------------------------
REM 2.5 FETCH & DISPLAY LATEST PATCH CHANGELOG
REM ----------------------------------------------------------------------------
curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "%PATCH_INFO_URL%?t=%RANDOM%" -o "%TEMP_PATCH_INFO%" 2>nul

if not exist "%TEMP_PATCH_INFO%" goto :skip_patch_info

echo %C_CYAN%============================================================================
echo                      LATEST PATCH DETAILS ^& CHANGELOG
echo ============================================================================%C_RESET%

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$installedPath = '!GAME_DIR!\BepInEx\patch_installed.txt'; $localVer = 'none'; if (Test-Path $installedPath) { $localVer = (Get-Content -Path $installedPath -Raw -ErrorAction SilentlyContinue).Trim() }; $info = Get-Content -Raw -Encoding UTF8 '%TEMP_PATCH_INFO%'; $sections = @(); $curVer = $null; $curHead = $null; $curLines = @(); foreach ($line in ($info -split '\r?\n')) { if ($line -match '===\s*\[(.*?)\]') { if ($curVer) { $sections += ,@($curVer, $curHead, $curLines) }; $curVer = $matches[1].Trim(); $curHead = $line; $curLines = @(); } elseif ($curVer) { $curLines += $line } }; if ($curVer) { $sections += ,@($curVer, $curHead, $curLines) }; if ($sections.Count -gt 0) { $latest = $sections[0][0].Trim(); if ($localVer.ToLower() -eq $latest.ToLower()) { Write-Host ' [STATUS] You are currently UP TO DATE on ' $latest -ForegroundColor Green; Write-Host ' Showing latest release notes:'; Write-Host (' ' + $sections[0][1]) -ForegroundColor Yellow; foreach ($l in $sections[0][2]) { if ($l -match '^\*') { Write-Host '    *' ($l.Substring(1)) -ForegroundColor Green } elseif ($l) { Write-Host ('   ' + $l) } } } else { if ($localVer -and $localVer -ne 'none') { Write-Host (' [STATUS] Updating from ' + $localVer + ' -> ' + $latest) -ForegroundColor Yellow; Write-Host (' New changes since your installed version (' + $localVer + '):`n') -ForegroundColor Green } else { Write-Host (' [STATUS] Installing latest patch: ' + $latest + '`n') -ForegroundColor Green }; foreach ($sec in $sections) { if ($localVer -and $sec[0].ToLower() -eq $localVer.ToLower()) { break }; Write-Host (' ' + $sec[1]) -ForegroundColor Yellow; foreach ($l in $sec[2]) { if ($l -match '^\*') { Write-Host '    *' ($l.Substring(1)) -ForegroundColor Green } elseif ($l) { Write-Host ('   ' + $l) } }; Write-Host '' } }; [System.IO.File]::WriteAllText($installedPath, $latest) }"

echo %C_CYAN%============================================================================%C_RESET%
echo.
del /f /q "%TEMP_PATCH_INFO%" 2>nul

:skip_patch_info

REM ----------------------------------------------------------------------------
REM 3. STAGE 1: DELETE OBSOLETE FILES & FOLDERS
REM ----------------------------------------------------------------------------
echo %C_CYAN%[1/3]%C_RESET% Checking for obsolete files and folders to remove...
curl.exe -s -L -f "%DELETE_LIST_URL%" -o "%TEMP_DELETE_LIST%"

if exist "%TEMP_DELETE_LIST%" (
    set "DELETED_COUNT=0"
    for /f "usebackq eol=# delims=" %%A in ("%TEMP_DELETE_LIST%") do (
        set "ITEM_PATH=%%A"
        REM Trim any leading/trailing spaces
        for /f "tokens=* delims= " %%B in ("!ITEM_PATH!") do set "ITEM_PATH=%%B"
        REM Normalize forward slashes to backslashes
        set "NORM_PATH=!ITEM_PATH:/=\!"

        if defined NORM_PATH (
            REM Distinguish between directory and file
            if exist "!GAME_DIR!\!NORM_PATH!\" (
                echo   %C_YELLOW%[-]%C_RESET% Removing folder: !NORM_PATH!
                rmdir /s /q "!GAME_DIR!\!NORM_PATH!" 2>nul
                set /a DELETED_COUNT+=1
            ) else if exist "!GAME_DIR!\!NORM_PATH!" (
                echo   %C_YELLOW%[-]%C_RESET% Removing file:   !NORM_PATH!
                del /f /q /a "!GAME_DIR!\!NORM_PATH!" 2>nul
                set /a DELETED_COUNT+=1
            )
        )
    )
    if !DELETED_COUNT! equ 0 (
        echo   No obsolete files or folders matched for deletion.
    ) else (
        echo   Cleaned up !DELETED_COUNT! obsolete item^(s^).
    )
    del /f /q "%TEMP_DELETE_LIST%" 2>nul
) else (
    echo   No deletion list found or nothing to remove. Continuing...
)
echo.

REM ----------------------------------------------------------------------------
REM 4. STAGE 2: DOWNLOAD MOD ARCHIVE
REM ----------------------------------------------------------------------------
echo %C_CYAN%[2/3]%C_RESET% Downloading latest mod patch (patch.zip)...
echo       Source: %REPO_USER%/%REPO_NAME% (%BRANCH%)
echo.
curl.exe -L -f --progress-bar "%PATCH_ZIP_URL%" -o "%TEMP_PATCH_ZIP%"

if errorlevel 1 (
    goto :err_download_failed
)

REM Verify file size of the downloaded zip
for %%F in ("%TEMP_PATCH_ZIP%") do (
    if %%~zF equ 0 (
        goto :err_empty_zip
    )
)
echo.

REM ----------------------------------------------------------------------------
REM 5. STAGE 3: EXTRACT MODS & OVERWRITE
REM ----------------------------------------------------------------------------
echo %C_CYAN%[3/3]%C_RESET% Extracting mod files and updating game directory...
tar.exe -xf "%TEMP_PATCH_ZIP%" -C "!GAME_DIR!"

if errorlevel 1 (
    goto :err_extract_failed
)

REM Cleanup temporary archive
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul

echo.
echo %C_GREEN%============================================================================
echo [SUCCESS] Lethal Company mods have been successfully synchronized.
echo ============================================================================%C_RESET%
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=Press [ENTER] to launch Lethal Company, or close this window to exit: "

if /i "!USER_CHOICE!"=="q" exit /b 0
if /i "!USER_CHOICE!"=="quit" exit /b 0
if /i "!USER_CHOICE!"=="exit" exit /b 0
if /i "!USER_CHOICE!"=="n" exit /b 0
if /i "!USER_CHOICE!"=="no" exit /b 0

echo.
echo %C_CYAN%Launching Lethal Company...%C_RESET%
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
timeout /t 1 >nul 2>&1
exit


REM ============================================================================
REM ERROR HANDLERS
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

:err_download_failed
echo.
echo %C_RED%[ERROR] Failed to download patch.zip from GitHub.%C_RESET%
echo.
echo Possible reasons:
echo  - Invalid repository configuration (User: %REPO_USER%, Repo: %REPO_NAME%, Branch: %BRANCH%)
echo  - The remote "patch.zip" does not exist in the repository
echo  - Network connectivity issues or GitHub rate limits
echo.
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul
pause
exit /b 1

:err_empty_zip
echo.
echo %C_RED%[ERROR] Downloaded patch.zip is empty (0 bytes).%C_RESET%
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul
pause
exit /b 1

:err_extract_failed
echo.
echo %C_RED%[ERROR] Extraction failed. Ensure game files are not locked by a running instance of Lethal Company.%C_RESET%
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul
pause
exit /b 1
