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
set "PATCHER_VERSION=20260826181409"

REM Script directory and config path
set "SCRIPT_DIR=%~dp0"
set "CONFIG_DIR=%LOCALAPPDATA%\LCModsPatcher"
set "CONFIG_FILE=%CONFIG_DIR%\lc_game_path.txt"
set "OPT_STATE_FILE=%CONFIG_DIR%\optimizer_state.txt"

REM Initialize ANSI color codes
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_WHITE=%ESC%[97m"
set "C_GRAY=%ESC%[90m"
set "C_BOLD=%ESC%[1m"
set "C_RESET=%ESC%[0m"

echo %C_CYAN%============================================================================
echo                        Lethal Company Mod Patcher
echo ============================================================================%C_RESET%
echo.

set "COMMIT_REF=%BRANCH%"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO_USER%/%REPO_NAME%/commits/%BRANCH%' -Headers @{'User-Agent'='LC-Mods-Patcher'} -TimeoutSec 3).sha } catch {}" 2^>nul`) do (
    if not "%%S"=="" set "COMMIT_REF=%%S"
)

REM ----------------------------------------------------------------------------
REM 0. SELF-UPDATE CHECK (Always executed FIRST before directory detection)
REM ----------------------------------------------------------------------------
if not defined _LC_PATCHER_SELF_UPDATED (
    rem Don't overwrite if running inside git repo working directory
    if not exist "%SCRIPT_DIR%.git" (
        echo %C_CYAN%[1/2]%C_RESET% Checking for patcher script updates on GitHub...
        set "SCRIPT_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/!COMMIT_REF!/lethal_company_patcher.bat"
        set "TEMP_SCRIPT=%TEMP%\lc_patcher_update_%RANDOM%.bat"

        curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!SCRIPT_URL!" -o "!TEMP_SCRIPT!" 2>nul
        if not exist "!TEMP_SCRIPT!" (
            curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/lethal_company_patcher.bat?t=%RANDOM%%RANDOM%" -o "!TEMP_SCRIPT!" 2>nul
        )
        if exist "!TEMP_SCRIPT!" (
            set "REMOTE_VERSION="
            for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$txt = Get-Content '!TEMP_SCRIPT!'; foreach($l in $txt){ if($l -match 'PATCHER_VERSION=(\d+)') { Write-Output $matches[1]; break } }"`) do (
                set "REMOTE_VERSION=%%V"
            )
            if defined REMOTE_VERSION (
                if !REMOTE_VERSION! gtr !PATCHER_VERSION! (
                    echo      %C_YELLOW%[UPDATE AVAILABLE]%C_RESET% Found newer build !REMOTE_VERSION! ^(Current: !PATCHER_VERSION!^)
                    echo      %C_CYAN%[+] Downloading and replacing script...%C_RESET%
                    set "_LC_PATCHER_SELF_UPDATED=1"
                    set "_LC_PREV_VERSION=!PATCHER_VERSION!"
                    copy /y "!TEMP_SCRIPT!" "%~f0" >nul
                    del /f /q "!TEMP_SCRIPT!" 2>nul
                    cmd.exe /c call "%~f0" %*
                    exit /b 0
                ) else (
                    echo      %C_GREEN%[UP TO DATE]%C_RESET% Running latest build !PATCHER_VERSION! ^(No update needed^)
                    set "PATCHER_STATUS_TEXT=%C_GREEN%[UP TO DATE] (Build !PATCHER_VERSION! - Synced with GitHub)%C_RESET%"
                )
            ) else (
                echo      %C_GREEN%[UP TO DATE]%C_RESET% Running build !PATCHER_VERSION!
                set "PATCHER_STATUS_TEXT=%C_GREEN%[UP TO DATE] (Build !PATCHER_VERSION!)%C_RESET%"
            )
            del /f /q "!TEMP_SCRIPT!" 2>nul
        ) else (
            echo      %C_GRAY%[OFFLINE / LOCAL]%C_RESET% Running local build !PATCHER_VERSION!
            set "PATCHER_STATUS_TEXT=%C_GRAY%[OFFLINE / LOCAL] (Build !PATCHER_VERSION!)%C_RESET%"
        )
        echo.
    ) else (
        set "PATCHER_STATUS_TEXT=%C_CYAN%[DEV MODE] (Build !PATCHER_VERSION! - Git Working Copy)%C_RESET%"
    )
) else (
    if defined _LC_PREV_VERSION (
        set "PATCHER_STATUS_TEXT=%C_GREEN%[JUST UPDATED] (Successfully upgraded from Build !_LC_PREV_VERSION! -> !PATCHER_VERSION!)%C_RESET%"
    ) else (
        set "PATCHER_STATUS_TEXT=%C_GREEN%[JUST UPDATED] (Successfully updated to Build !PATCHER_VERSION! from GitHub)%C_RESET%"
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
        for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut(\"%%~fF\").TargetPath; if(Test-Path $s){$s}" 2^>nul`) do (
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
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = \"Select your Lethal Company game folder\"; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$f.SelectedPath}"`) do set "INPUT_DIR=%%D"
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
echo                     Lethal Company Mod Patcher ^& Toolset
echo ============================================================================%C_RESET%
echo   %C_BOLD%%C_WHITE%Patcher Status:%C_RESET%  !PATCHER_STATUS_TEXT!
echo   %C_BOLD%%C_WHITE%Target Game Dir:%C_RESET% %C_CYAN%!GAME_DIR!%C_RESET%
if defined _LC_PATCHER_SELF_UPDATED (
    echo.
    echo   %C_GREEN%[+] PATCHER UPDATED:%C_RESET% %C_CYAN%Script was successfully auto-updated to build !PATCHER_VERSION! from GitHub.%C_RESET%
)
echo.
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo   Select an action:
echo     %C_GREEN%[ENTER]%C_RESET% -^> %C_GREEN%Update ^& Apply Latest Mods%C_RESET% ^(Default / Recommended^)
echo     %C_YELLOW%[1]%C_RESET%     -^> %C_YELLOW%Performance ^& Low-Spec Optimizer Tool%C_RESET%
echo     %C_CYAN%[2]%C_RESET%     -^> %C_CYAN%Debugging ^& Log Optimization Tool%C_RESET% ^(Full Debug vs Minimal Logs^)
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
if "!USER_ACTION!"=="2" goto :logging_menu
if /i "!USER_ACTION!"=="LOG" goto :logging_menu
if /i "!USER_ACTION!"=="LOGS" goto :logging_menu
if /i "!USER_ACTION!"=="DEBUG" goto :logging_menu
if /i "!USER_ACTION!"=="C" goto :prompt_custom_path
if /i "!USER_ACTION!"=="CHANGE" goto :prompt_custom_path
if /i "!USER_ACTION!"=="Q" exit /b 0
if /i "!USER_ACTION!"=="QUIT" exit /b 0
if /i "!USER_ACTION!"=="EXIT" exit /b 0
if "!USER_ACTION!"=="0" exit /b 0

REM If user typed anything else unrecognized, assume patcher flow
goto :run_patcher_flow


REM ============================================================================
REM FLOW 1: LOGGING & DEBUGGING SUBMENU
REM ============================================================================
:logging_menu
cls
echo %C_CYAN%============================================================================
echo                     BepInEx Logging ^& Debugging Tool
echo ============================================================================%C_RESET%
echo   Target Game:   %C_YELLOW%!GAME_DIR!%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%

set "PS_SCRIPT=%SCRIPT_DIR%optimizer\optimize.ps1"
set "PS_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/optimizer/optimize.ps1?t=%RANDOM%"
set "TEMP_PS=%TEMP%\lc_optimize_%RANDOM%.ps1"

if not exist "!PS_SCRIPT!" (
    curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!PS_URL!" -o "!TEMP_PS!" 2>nul
    if exist "!TEMP_PS!" set "PS_SCRIPT=!TEMP_PS!"
)

if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "LogCheck" -GameDir "!GAME_DIR!"
)
echo %C_CYAN%============================================================================%C_RESET%
echo.
echo   %C_GREEN%[1]%C_RESET% Set to Clean Console ^& High Performance (%C_GREEN%Loading Visible, Zero In-Game Lag%C_RESET%) %C_GREEN%(Recommended)%C_RESET%
echo   %C_YELLOW%[2]%C_RESET% Set to Diagnostic ^& Mod Debug Mode      (%C_YELLOW%Spawns Console, Captures Mod Debug/Info/Errors%C_RESET%)
echo   %C_WHITE%[3]%C_RESET% Set to Silent Background Mode        (%C_GRAY%Console Window Hidden%C_RESET%)
echo   %C_CYAN%[4]%C_RESET% Open LogOutput.log in Notepad
echo   %C_CYAN%[5]%C_RESET% Clear / Reset LogOutput.log File
echo   %C_CYAN%[B]%C_RESET% Back to Main Menu
echo   %C_RED%[Q]%C_RESET% Exit
echo.
set "LOG_CHOICE="
set /p "LOG_CHOICE=Select an option [1-5, B, Q] (Default: 1): "
if not defined LOG_CHOICE set "LOG_CHOICE=1"

if "%LOG_CHOICE%"=="1" (
    echo.
    if exist "!PS_SCRIPT!" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "LogMinimal" -GameDir "!GAME_DIR!"
    if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
    echo.
    pause
    goto :logging_menu
)
if "%LOG_CHOICE%"=="2" (
    echo.
    if exist "!PS_SCRIPT!" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "LogDebug" -GameDir "!GAME_DIR!"
    if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
    echo.
    pause
    goto :logging_menu
)
if "%LOG_CHOICE%"=="3" (
    echo.
    if exist "!PS_SCRIPT!" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "LogSilent" -GameDir "!GAME_DIR!"
    if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
    echo.
    pause
    goto :logging_menu
)
if "%LOG_CHOICE%"=="4" (
    if exist "!GAME_DIR!\BepInEx\LogOutput.log" (
        start notepad "!GAME_DIR!\BepInEx\LogOutput.log"
    ) else (
        echo %C_YELLOW%No LogOutput.log found in BepInEx folder.%C_RESET%
        pause
    )
    goto :logging_menu
)
if "%LOG_CHOICE%"=="5" (
    echo.
    if exist "!PS_SCRIPT!" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "LogClear" -GameDir "!GAME_DIR!"
    if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
    echo.
    pause
    goto :logging_menu
)
if /i "%LOG_CHOICE%"=="B" goto :main_menu
if /i "%LOG_CHOICE%"=="BACK" goto :main_menu
if /i "%LOG_CHOICE%"=="Q" exit /b 0
if /i "%LOG_CHOICE%"=="QUIT" exit /b 0
goto :logging_menu


REM ============================================================================
REM FLOW 2: PERFORMANCE OPTIMIZER SUBMENU (WITH LIVE CHECKLIST)
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

if "%OPT_CHOICE%"=="1" goto :do_apply_optimizer_menu
if "%OPT_CHOICE%"=="2" goto :do_revert_optimizer
if "%OPT_CHOICE%"=="3" goto :do_launch_from_optimizer
if /i "%OPT_CHOICE%"=="B" goto :main_menu
if /i "%OPT_CHOICE%"=="BACK" goto :main_menu
if /i "%OPT_CHOICE%"=="Q" exit /b 0
if /i "%OPT_CHOICE%"=="QUIT" exit /b 0
if "%OPT_CHOICE%"=="0" exit /b 0
goto :optimizer_menu

:do_apply_optimizer_menu
cls
echo %C_CYAN%============================================================================
echo                     Apply Performance Optimizations
echo ============================================================================%C_RESET%
echo.
echo   %C_GREEN%[1]%C_RESET% Quick Apply Preset       -^> Apply recommended FPS optimizations in 1 click
echo   %C_GREEN%[2]%C_RESET% Step-by-Step Custom Mode -^> Choose each setting individually ^(Bodycam, Fog, etc.^)
echo   %C_CYAN%[B]%C_RESET% Back to Optimizer Menu
echo.
set "APPLY_MODE="
set /p "APPLY_MODE=Select mode [1, 2, B] (Default: [ENTER] for Quick Apply): "
if not defined APPLY_MODE set "APPLY_MODE=1"

if /i "%APPLY_MODE%"=="B" goto :optimizer_menu
if /i "%APPLY_MODE%"=="BACK" goto :optimizer_menu
if /i "%APPLY_MODE%"=="Y" set "APPLY_MODE=1"
if /i "%APPLY_MODE%"=="YES" set "APPLY_MODE=1"
if /i "%APPLY_MODE%"=="N" set "APPLY_MODE=2"
if /i "%APPLY_MODE%"=="NO" set "APPLY_MODE=2"

if "%APPLY_MODE%"=="2" goto :do_step_by_step_wizard

REM ----------------------------------------------------------------------------
REM QUICK APPLY RESOLUTION PRESET
REM ----------------------------------------------------------------------------
cls
echo %C_CYAN%============================================================================
echo                   Select Graphics ^& Resolution Profile
echo ============================================================================%C_RESET%
echo.
echo   %C_GREEN%[1]%C_RESET% High               -^> %C_YELLOW%1.2x Res%C_RESET%  ^(Crisp visuals, High-End GPU^)
echo   %C_GREEN%[2]%C_RESET% Default / Balanced -^> %C_YELLOW%1.0x Res%C_RESET%  ^(Native 1080p/1440p standard^)
echo   %C_GREEN%[3]%C_RESET% Performance        -^> %C_YELLOW%0.7x Res%C_RESET%  ^(Recommended: +35%% FPS Boost for Mid/Low PC^)
echo   %C_GREEN%[4]%C_RESET% Ultra Performance  -^> %C_YELLOW%0.5x Res%C_RESET%  ^(Maximum FPS: +60%% Boost for Potato PC / iGPU^)
echo   %C_CYAN%[B]%C_RESET% Back to Optimizer Menu
echo.
set "PROFILE_CHOICE="
set /p "PROFILE_CHOICE=Select resolution profile [1-4, B] (Default: 3): "
if not defined PROFILE_CHOICE set "PROFILE_CHOICE=3"

if /i "%PROFILE_CHOICE%"=="B" goto :optimizer_menu
if /i "%PROFILE_CHOICE%"=="BACK" goto :optimizer_menu

set "TARGET_SCALE=0.7"
if "%PROFILE_CHOICE%"=="1" set "TARGET_SCALE=1.2"
if "%PROFILE_CHOICE%"=="2" set "TARGET_SCALE=1.0"
if "%PROFILE_CHOICE%"=="3" set "TARGET_SCALE=0.7"
if "%PROFILE_CHOICE%"=="4" set "TARGET_SCALE=0.5"

echo.
echo %C_CYAN%[1/2] Applying Performance Optimizations (!TARGET_SCALE!x Res)...%C_RESET%
if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "Optimize" -ResolutionScale "!TARGET_SCALE!" -GameDir "!GAME_DIR!"
)
echo.
echo %C_CYAN%[2/2] Synchronizing FPS Counter overlay plugin...%C_RESET%
curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!OPT_ZIP_URL!" -o "!TEMP_OPT_ZIP!" 2>nul
if exist "!TEMP_OPT_ZIP!" (
    tar.exe -xf "!TEMP_OPT_ZIP!" -C "!GAME_DIR!" 2>nul
    del /f /q "!TEMP_OPT_ZIP!" 2>nul
)
if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
(
    echo RES=!TARGET_SCALE!
    echo BC=yes
    echo SC=yes
    echo SW=yes
    echo HDRP=yes
    echo FPS=yes
)>"!OPT_STATE_FILE!" 2>nul
echo.
echo %C_GREEN%[SUCCESS] Performance Optimizations Applied with !TARGET_SCALE!x Resolution Scale!%C_RESET%
echo.
pause
goto :optimizer_menu

REM ----------------------------------------------------------------------------
REM STEP-BY-STEP CUSTOM WIZARD (AUTO-REMEMBERS PREVIOUS SETTINGS)
REM ----------------------------------------------------------------------------
:do_step_by_step_wizard
cls

REM Default values
set "DEF_WIZ_RES=3"
set "DEF_WIZ_RES_LABEL=0.7x"
set "DEF_WIZ_BC=Y"
set "DEF_WIZ_SC=Y"
set "DEF_WIZ_SW=Y"
set "DEF_WIZ_HDRP=Y"
set "DEF_WIZ_FPS=Y"

REM Load previously saved wizard choices if available
if exist "!OPT_STATE_FILE!" (
    for /f "usebackq tokens=1,2 delims==" %%A in ("!OPT_STATE_FILE!") do (
        if /i "%%A"=="RES" (
            if "%%B"=="1.2" (set "DEF_WIZ_RES=1" & set "DEF_WIZ_RES_LABEL=1.2x")
            if "%%B"=="1.0" (set "DEF_WIZ_RES=2" & set "DEF_WIZ_RES_LABEL=1.0x")
            if "%%B"=="0.7" (set "DEF_WIZ_RES=3" & set "DEF_WIZ_RES_LABEL=0.7x")
            if "%%B"=="0.5" (set "DEF_WIZ_RES=4" & set "DEF_WIZ_RES_LABEL=0.5x")
        )
        if /i "%%A"=="BC" (
            if /i "%%B"=="yes" set "DEF_WIZ_BC=Y"
            if /i "%%B"=="no" set "DEF_WIZ_BC=N"
        )
        if /i "%%A"=="SC" (
            if /i "%%B"=="yes" set "DEF_WIZ_SC=Y"
            if /i "%%B"=="no" set "DEF_WIZ_SC=N"
        )
        if /i "%%A"=="SW" (
            if /i "%%B"=="yes" set "DEF_WIZ_SW=Y"
            if /i "%%B"=="no" set "DEF_WIZ_SW=N"
        )
        if /i "%%A"=="HDRP" (
            if /i "%%B"=="yes" set "DEF_WIZ_HDRP=Y"
            if /i "%%B"=="no" set "DEF_WIZ_HDRP=N"
        )
        if /i "%%A"=="FPS" (
            if /i "%%B"=="yes" set "DEF_WIZ_FPS=Y"
            if /i "%%B"=="no" set "DEF_WIZ_FPS=N"
        )
    )
) else (
    REM Auto-detect from currently active config files if never saved
    set "LC_CFG=!GAME_DIR!\BepInEx\config\com.github.lethalcompanymodding.LCUltrawide.cfg"
    if exist "!LC_CFG!" (
        findstr /i /c:"Gameplay Camera Resolution Multiplier = 1.2" "!LC_CFG!" >nul 2>&1 && (set "DEF_WIZ_RES=1" & set "DEF_WIZ_RES_LABEL=1.2x")
        findstr /i /c:"Gameplay Camera Resolution Multiplier = 1" "!LC_CFG!" >nul 2>&1 && (set "DEF_WIZ_RES=2" & set "DEF_WIZ_RES_LABEL=1.0x")
        findstr /i /c:"Gameplay Camera Resolution Multiplier = 0.7" "!LC_CFG!" >nul 2>&1 && (set "DEF_WIZ_RES=3" & set "DEF_WIZ_RES_LABEL=0.7x")
        findstr /i /c:"Gameplay Camera Resolution Multiplier = 0.5" "!LC_CFG!" >nul 2>&1 && (set "DEF_WIZ_RES=4" & set "DEF_WIZ_RES_LABEL=0.5x")
    )
    set "OBC_CFG=!GAME_DIR!\BepInEx\config\Zaggy1024.OpenBodyCams.cfg"
    if exist "!OBC_CFG!" (
        findstr /i /c:"EnableCamera = true" "!OBC_CFG!" >nul 2>&1 && set "DEF_WIZ_BC=N"
        findstr /i /c:"EnableCamera = false" "!OBC_CFG!" >nul 2>&1 && set "DEF_WIZ_BC=Y"
    )
    set "GI_CFG=!GAME_DIR!\BepInEx\config\ShaosilGaming.GeneralImprovements.cfg"
    if exist "!GI_CFG!" (
        findstr /i /c:"ShipExternalCamFPS = 5" "!GI_CFG!" >nul 2>&1 && set "DEF_WIZ_SC=Y"
        findstr /i /c:"ShipExternalCamFPS = 10" "!GI_CFG!" >nul 2>&1 && set "DEF_WIZ_SC=N"
    )
    set "SW_CFG=!GAME_DIR!\BepInEx\config\TestAccount666.ShipWindows.cfg"
    if exist "!SW_CFG!" (
        findstr /i /c:"Skybox Type = BLACK_AND_STARS" "!SW_CFG!" >nul 2>&1 && set "DEF_WIZ_SW=Y"
        findstr /i /c:"Skybox Type = REAL" "!SW_CFG!" >nul 2>&1 && set "DEF_WIZ_SW=N"
    )
    set "SPONGE_CFG=!GAME_DIR!\BepInEx\config\LethalSponge.cfg"
    if exist "!SPONGE_CFG!" (
        findstr /i /c:"shadowsMaxResolution = 64" "!SPONGE_CFG!" >nul 2>&1 && set "DEF_WIZ_HDRP=Y"
        findstr /i /c:"shadowsMaxResolution = 2048" "!SPONGE_CFG!" >nul 2>&1 && set "DEF_WIZ_HDRP=N"
    )
    if not exist "!GAME_DIR!\BepInEx\plugins\LC_FPSCounter\LC_FPSCounter.dll" set "DEF_WIZ_FPS=N"
)

echo %C_CYAN%============================================================================
echo               Custom Step-by-Step Performance Optimizer Wizard
echo ============================================================================%C_RESET%
echo.

REM ----------------------------------------------------------------------------
REM Step 1: Resolution Scale
REM ----------------------------------------------------------------------------
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  %C_BOLD%%C_WHITE%[STEP 1 / 6]%C_RESET% %C_CYAN%Resolution Scaling Multiplier%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  Controls the 3D render resolution. Lowering provides massive GPU FPS gains.
echo.
echo   %C_GREEN%[1]%C_RESET% High               : %C_YELLOW%1.2x Scale%C_RESET%  (Crisp 1440p+ visuals, High-End GPU)
echo   %C_GREEN%[2]%C_RESET% Default / Baseline : %C_YELLOW%1.0x Scale%C_RESET%  (Native 1080p standard resolution)
echo   %C_GREEN%[3]%C_RESET% Performance        : %C_YELLOW%0.7x Scale%C_RESET%  (%C_CYAN%+25%% to +35%% FPS Boost%C_RESET%) %C_GREEN%[Recommended]%C_RESET%
echo   %C_GREEN%[4]%C_RESET% Ultra Performance  : %C_YELLOW%0.5x Scale%C_RESET%  (%C_CYAN%+45%% to +60%% FPS Boost%C_RESET%) %C_YELLOW%[Max FPS for iGPU]%C_RESET%
echo.
set "WIZ_RES="
set /p "WIZ_RES=Select resolution [1-4] (Default: [ENTER] for Option !DEF_WIZ_RES! - !DEF_WIZ_RES_LABEL!): "
if not defined WIZ_RES set "WIZ_RES=!DEF_WIZ_RES!"
set "TARGET_SCALE=0.7"
if "%WIZ_RES%"=="1" set "TARGET_SCALE=1.2"
if "%WIZ_RES%"=="2" set "TARGET_SCALE=1.0"
if "%WIZ_RES%"=="3" set "TARGET_SCALE=0.7"
if "%WIZ_RES%"=="4" set "TARGET_SCALE=0.5"
echo  %C_GREEN%-[+] Selected:%C_RESET% !TARGET_SCALE!x Resolution Scale
echo.

REM ----------------------------------------------------------------------------
REM Step 2: BodyCam Overhead
REM ----------------------------------------------------------------------------
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  %C_BOLD%%C_WHITE%[STEP 2 / 5]%C_RESET% %C_CYAN%OpenBodyCams 3D Camera Overhead%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  Disables redundant secondary 3D camera rendering on chest rigs ^& terminals.
echo  %C_YELLOW%Benefit:%C_RESET% %C_CYAN%+15%% to +20%% FPS Boost%C_RESET%, saves ~500MB VRAM
echo.
set "BC_PROMPT_LABEL=[Y/n] (Default: [ENTER] for Yes)"
set "BC_TAG_Y=%C_GREEN%[Currently Active]%C_RESET%"
set "BC_TAG_N="
if /i "!DEF_WIZ_BC!"=="N" set "BC_PROMPT_LABEL=[y/N] (Default: [ENTER] for No)"
if /i "!DEF_WIZ_BC!"=="N" set "BC_TAG_Y="
if /i "!DEF_WIZ_BC!"=="N" set "BC_TAG_N=%C_YELLOW%[Currently Active]%C_RESET%"

echo   %C_GREEN%[Y]%C_RESET% Yes - Disable 3D Bodycam overhead !BC_TAG_Y!
echo   %C_YELLOW%[N]%C_RESET% No  - Keep original full 3D bodycam rendering !BC_TAG_N!
echo.
set "WIZ_BC="
set /p "WIZ_BC=Apply BodyCam Optimization? !BC_PROMPT_LABEL!: "
if not defined WIZ_BC set "WIZ_BC=!DEF_WIZ_BC!"
set "OPT_BC=yes"
if /i "%WIZ_BC%"=="N" set "OPT_BC=no"
if /i "%WIZ_BC%"=="NO" set "OPT_BC=no"
echo  %C_GREEN%-[+] Selected:%C_RESET% BodyCam Optimization = !OPT_BC!
echo.

REM ----------------------------------------------------------------------------
REM Step 3: Ship Security Cameras
REM ----------------------------------------------------------------------------
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  %C_BOLD%%C_WHITE%[STEP 3 / 5]%C_RESET% %C_CYAN%Ship Security ^& Monitor Camera Framerates%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  Caps ship interior and security camera refresh rates to 5 FPS.
echo  %C_YELLOW%Benefit:%C_RESET% %C_CYAN%+8%% to +12%% FPS Boost%C_RESET% inside the ship
echo.
set "SC_PROMPT_LABEL=[Y/n] (Default: [ENTER] for Yes)"
set "SC_TAG_Y=%C_GREEN%[Currently Active]%C_RESET%"
set "SC_TAG_N="
if /i "!DEF_WIZ_SC!"=="N" set "SC_PROMPT_LABEL=[y/N] (Default: [ENTER] for No)"
if /i "!DEF_WIZ_SC!"=="N" set "SC_TAG_Y="
if /i "!DEF_WIZ_SC!"=="N" set "SC_TAG_N=%C_YELLOW%[Currently Active]%C_RESET%"

echo   %C_GREEN%[Y]%C_RESET% Yes - Cap monitor cameras to 5 FPS !SC_TAG_Y!
echo   %C_YELLOW%[N]%C_RESET% No  - Keep default 10+ FPS monitor refresh !SC_TAG_N!
echo.
set "WIZ_SC="
set /p "WIZ_SC=Cap Ship Cameras? !SC_PROMPT_LABEL!: "
if not defined WIZ_SC set "WIZ_SC=!DEF_WIZ_SC!"
set "OPT_SC=yes"
if /i "%WIZ_SC%"=="N" set "OPT_SC=no"
if /i "%WIZ_SC%"=="NO" set "OPT_SC=no"
echo  %C_GREEN%-[+] Selected:%C_RESET% Ship Cameras Cap = !OPT_SC!
echo.

REM ----------------------------------------------------------------------------
REM Step 4: ShipWindows Exterior Skybox
REM ----------------------------------------------------------------------------
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  %C_BOLD%%C_WHITE%[STEP 4 / 5]%C_RESET% %C_CYAN%ShipWindows Exterior Skybox ^& Planet Culling%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  Replaces heavy real-time planet exterior skybox with space starfield.
echo  %C_YELLOW%Benefit:%C_RESET% %C_CYAN%+10%% to +15%% FPS Boost%C_RESET% during landing ^& orbit
echo.
set "SW_PROMPT_LABEL=[Y/n] (Default: [ENTER] for Yes)"
set "SW_TAG_Y=%C_GREEN%[Currently Active]%C_RESET%"
set "SW_TAG_N="
if /i "!DEF_WIZ_SW!"=="N" set "SW_PROMPT_LABEL=[y/N] (Default: [ENTER] for No)"
if /i "!DEF_WIZ_SW!"=="N" set "SW_TAG_Y="
if /i "!DEF_WIZ_SW!"=="N" set "SW_TAG_N=%C_YELLOW%[Currently Active]%C_RESET%"

echo   %C_GREEN%[Y]%C_RESET% Yes - Use space starfield ^& planet culling !SW_TAG_Y!
echo   %C_YELLOW%[N]%C_RESET% No  - Keep default heavy exterior meshes !SW_TAG_N!
echo.
set "WIZ_SW="
set /p "WIZ_SW=Optimize ShipWindows? !SW_PROMPT_LABEL!: "
if not defined WIZ_SW set "WIZ_SW=!DEF_WIZ_SW!"
set "OPT_SW=yes"
if /i "%WIZ_SW%"=="N" set "OPT_SW=no"
if /i "%WIZ_SW%"=="NO" set "OPT_SW=no"
echo  %C_GREEN%-[+] Selected:%C_RESET% ShipWindows Optimization = !OPT_SW!
echo.

REM ----------------------------------------------------------------------------
REM Step 5: HDRP Fog & Shadows
REM ----------------------------------------------------------------------------
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  %C_BOLD%%C_WHITE%[STEP 5 / 5]%C_RESET% %C_CYAN%LethalSponge HDRP Fog Budget ^& Shadow Maps%C_RESET%
echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo  Lowers heavy volumetric fog budget (0.05) and shadow maps (64px).
echo  %C_YELLOW%Benefit:%C_RESET% %C_CYAN%+12%% to +18%% FPS Boost%C_RESET% in foggy ^& stormy weather
echo.
set "HDRP_PROMPT_LABEL=[Y/n] (Default: [ENTER] for Yes)"
set "HDRP_TAG_Y=%C_GREEN%[Currently Active]%C_RESET%"
set "HDRP_TAG_N="
if /i "!DEF_WIZ_HDRP!"=="N" set "HDRP_PROMPT_LABEL=[y/N] (Default: [ENTER] for No)"
if /i "!DEF_WIZ_HDRP!"=="N" set "HDRP_TAG_Y="
if /i "!DEF_WIZ_HDRP!"=="N" set "HDRP_TAG_N=%C_YELLOW%[Currently Active]%C_RESET%"

echo   %C_GREEN%[Y]%C_RESET% Yes - Apply low-spec shadows and fog !HDRP_TAG_Y!
echo   %C_YELLOW%[N]%C_RESET% No  - Keep high default HDRP shadows and volumetric fog !HDRP_TAG_N!
echo.
set "WIZ_HDRP="
set /p "WIZ_HDRP=Optimize Shadows and Fog? !HDRP_PROMPT_LABEL!: "
if not defined WIZ_HDRP set "WIZ_HDRP=!DEF_WIZ_HDRP!"
set "OPT_HDRP=yes"
if /i "%WIZ_HDRP%"=="N" set "OPT_HDRP=no"
if /i "%WIZ_HDRP%"=="NO" set "OPT_HDRP=no"
echo  %C_GREEN%-[+] Selected:%C_RESET% HDRP Fog ^& Shadows = !OPT_HDRP!
echo.

echo %C_CYAN%----------------------------------------------------------------------------%C_RESET%
echo %C_CYAN%Applying custom optimization settings...%C_RESET%
if exist "!PS_SCRIPT!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" -Mode "Custom" -ResolutionScale "!TARGET_SCALE!" -OptBodyCam "!OPT_BC!" -OptShipCameras "!OPT_SC!" -OptShipWindows "!OPT_SW!" -OptHDRP "!OPT_HDRP!" -GameDir "!GAME_DIR!"
)

if exist "!TEMP_PS!" del /f /q "!TEMP_PS!" 2>nul
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
(
    echo RES=!TARGET_SCALE!
    echo BC=!OPT_BC!
    echo SC=!OPT_SC!
    echo SW=!OPT_SW!
    echo HDRP=!OPT_HDRP!
)>"!OPT_STATE_FILE!" 2>nul
echo.
echo %C_GREEN%============================================================================
echo [SUCCESS] Custom performance settings have been applied successfully!
echo ============================================================================%C_RESET%
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
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
(
    echo RES=1.0
    echo BC=no
    echo SC=no
    echo SW=no
    echo HDRP=no
    echo FPS=no
)>"!OPT_STATE_FILE!" 2>nul
echo.
echo %C_GREEN%[SUCCESS] Reverted to Standard Default Graphics.%C_RESET%
echo.
pause
goto :optimizer_menu

:do_launch_from_optimizer
echo.
echo %C_CYAN%============================================================================
echo [+] Launching Lethal Company with BepInEx Modding Engine...
echo [i] Loading 40+ mods (Initial boot takes ~15-30s on lower-spec systems).
echo [i] The black BepInEx console window will display active plugin progress.
echo ============================================================================%C_RESET%
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
timeout /t 3 >nul 2>&1
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
set "DELETE_LIST_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/!COMMIT_REF!/delete_list.txt"
set "PATCH_ZIP_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/!COMMIT_REF!/patch.zip"
set "PATCH_INFO_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/!COMMIT_REF!/patch_info.txt"
set "TEMP_DELETE_LIST=%TEMP%\lc_delete_list_%RANDOM%.txt"
set "TEMP_PATCH_ZIP=%TEMP%\lc_patch_%RANDOM%.zip"
set "TEMP_PATCH_INFO=%TEMP%\lc_patch_info_%RANDOM%.txt"

REM ----------------------------------------------------------------------------
REM 2.5 FETCH & DISPLAY LATEST PATCH CHANGELOG
REM ----------------------------------------------------------------------------
curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!PATCH_INFO_URL!" -o "%TEMP_PATCH_INFO%" 2>nul
if not exist "%TEMP_PATCH_INFO%" (
    curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/patch_info.txt?t=%RANDOM%%RANDOM%" -o "%TEMP_PATCH_INFO%" 2>nul
)

if not exist "%TEMP_PATCH_INFO%" goto :skip_patch_info

echo %C_CYAN%============================================================================
echo                      LATEST PATCH DETAILS ^& CHANGELOG
echo ============================================================================%C_RESET%

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$installedPath = '!GAME_DIR!\BepInEx\patch_installed.txt'; $localVer = 'none'; if (Test-Path $installedPath) { $localVer = (Get-Content -Path $installedPath -Raw -ErrorAction SilentlyContinue).Trim() }; $info = Get-Content -Raw -Encoding UTF8 '%TEMP_PATCH_INFO%'; $sections = @(); $curVer = $null; $curHead = $null; $curLines = @(); foreach ($line in ($info -split '\r?\n')) { if ($line -match '===\s*\[(.*?)\]') { if ($curVer) { $sections += ,@($curVer, $curHead, $curLines) }; $curVer = $matches[1].Trim(); $curHead = $line; $curLines = @(); } elseif ($curVer) { $curLines += $line } }; if ($curVer) { $sections += ,@($curVer, $curHead, $curLines) }; if ($sections.Count -gt 0) { $latest = $sections[0][0].Trim(); $maxW = 80; try { $maxW = [Math]::Max(60, [Math]::Min(100, $Host.UI.RawUI.WindowSize.Width - 4)) } catch {}; $printLines = { param($arr) foreach ($l in $arr) { if ([string]::IsNullOrWhiteSpace($l)) { Write-Host ''; continue }; $trimmed = $l.Trim(); $lead = $l.Length - $l.TrimStart().Length; $pfx = '    '; $ind = '    '; $col = 'White'; if ($trimmed.StartsWith('*')) { if ($lead -le 2) { $pfx = '  * '; $ind = '    '; $col = 'Green'; $trimmed = $trimmed.Substring(1).Trim() } else { $pfx = '      - '; $ind = '        '; $col = 'Cyan'; $trimmed = $trimmed.Substring(1).Trim() } } elseif ($trimmed.StartsWith('-')) { $pfx = '    - '; $ind = '      '; $col = 'White'; $trimmed = $trimmed.Substring(1).Trim() }; $words = $trimmed -split '\s+'; $cur = $pfx; $first = $true; foreach ($w in $words) { if ($first) { $cur += $w; $first = $false } elseif (($cur.Length + 1 + $w.Length) -le $maxW) { $cur += ' ' + $w } else { Write-Host $cur -ForegroundColor $col; $cur = $ind + $w } }; if ($cur.Trim().Length -gt 0) { Write-Host $cur -ForegroundColor $col } } }; if ($localVer.ToLower() -eq $latest.ToLower()) { Write-Host (' [STATUS] You are currently UP TO DATE on ' + $latest) -ForegroundColor Green; Write-Host ' Showing latest release notes:'; Write-Host (' ' + $sections[0][1]) -ForegroundColor Yellow; & $printLines $sections[0][2] } else { if ($localVer -and $localVer -ne 'none') { Write-Host (' [STATUS] Updating from ' + $localVer + ' -> ' + $latest) -ForegroundColor Yellow; Write-Host (' New changes since your installed version (' + $localVer + '):`n') -ForegroundColor Green } else { Write-Host (' [STATUS] Installing latest patch: ' + $latest + '`n') -ForegroundColor Green }; foreach ($sec in $sections) { if ($localVer -and $sec[0].ToLower() -eq $localVer.ToLower()) { break }; Write-Host (' ' + $sec[1]) -ForegroundColor Yellow; & $printLines $sec[2]; Write-Host '' } }; [System.IO.File]::WriteAllText($installedPath, $latest) }"

echo %C_CYAN%============================================================================%C_RESET%
echo.
del /f /q "%TEMP_PATCH_INFO%" 2>nul

:skip_patch_info

REM ----------------------------------------------------------------------------
REM 3. STAGE 1: DELETE OBSOLETE FILES & FOLDERS
REM ----------------------------------------------------------------------------
echo %C_CYAN%[1/3]%C_RESET% Checking for obsolete files and folders to remove...
curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!DELETE_LIST_URL!" -o "%TEMP_DELETE_LIST%" 2>nul
if not exist "%TEMP_DELETE_LIST%" (
    curl.exe -s -m 5 -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/delete_list.txt?t=%RANDOM%%RANDOM%" -o "%TEMP_DELETE_LIST%" 2>nul
)

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
echo       Source: %REPO_USER%/%REPO_NAME% (%BRANCH% @ !COMMIT_REF:~0,7!)
echo.
curl.exe -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" --progress-bar "!PATCH_ZIP_URL!" -o "%TEMP_PATCH_ZIP%"
if errorlevel 1 (
    curl.exe -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" --progress-bar "https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/patch.zip?t=%RANDOM%%RANDOM%" -o "%TEMP_PATCH_ZIP%"
)

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
echo %C_CYAN%============================================================================
echo [+] Launching Lethal Company with BepInEx Modding Engine...
echo [i] Loading 40+ mods (Initial boot takes ~15-30s on lower-spec systems).
echo [i] The black BepInEx console window will display active plugin progress.
echo ============================================================================%C_RESET%
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
timeout /t 3 >nul 2>&1
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
