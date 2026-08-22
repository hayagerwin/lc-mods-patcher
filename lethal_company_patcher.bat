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
        set "SCRIPT_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/lethal_company_patcher.bat?t=%RANDOM%"
        set "TEMP_SCRIPT=%TEMP%\lc_patcher_update_%RANDOM%.bat"

        curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "!SCRIPT_URL!" -o "!TEMP_SCRIPT!" 2>nul
        if exist "!TEMP_SCRIPT!" (
            for %%F in ("!TEMP_SCRIPT!") do (
                if %%~zF gtr 0 (
                    fc.exe /b "%~f0" "!TEMP_SCRIPT!" >nul 2>nul
                    if errorlevel 1 (
                        echo %C_CYAN%[UPDATE]%C_RESET% A newer version of lethal_company_patcher.bat was detected.
                        echo %C_CYAN%[UPDATE]%C_RESET% Updating script and restarting...
                        echo.
                        set "_LC_PATCHER_SELF_UPDATED=1"
                        copy /y "!TEMP_SCRIPT!" "%~f0" >nul & del /f /q "!TEMP_SCRIPT!" 2>nul & call "%~f0" %* & exit /b !errorlevel!
                    )
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

REM Scan Nested folder inside SCRIPT_DIR (e.g. extracted alongside game subfolder)
for /d %%S in ("%SCRIPT_DIR%*Lethal*" "%SCRIPT_DIR%*") do (
    if exist "%%~fS\Lethal Company.exe" (
        if not defined FOUND_DIR_%%~fS (
            set "FOUND_DIR_%%~fS=1"
            set /a COUNT+=1
            for %%K in (!COUNT!) do (
                set "CANDIDATE_%%K=%%~fS"
                set "LABEL_%%K=Inside Current Folder"
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
                    set "LABEL_%%K=Inside Current Folder"
                )
            )
        )
    )
)

REM Scan Saved Location
if exist "%CONFIG_FILE%" (
    set /p SAVED_P=<"%CONFIG_FILE%"
    if defined SAVED_P (
        set "SAVED_P=!SAVED_P:"=!"
        if exist "!SAVED_P!\Lethal Company.exe" (
            if not defined FOUND_DIR_!SAVED_P! (
                set "FOUND_DIR_!SAVED_P!=1"
                set /a COUNT+=1
                for %%K in (!COUNT!) do (
                    set "CANDIDATE_%%K=!SAVED_P!"
                    set "LABEL_%%K=Previously Used"
                )
            )
        ) else (
            for /d %%S in ("!SAVED_P!\*") do (
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
            REM Subfolder depth 1 check (e.g. Downloads/Lethal Company/Lethal Company)
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
    echo   %C_GREEN%[!CUSTOM_OPT!]%C_RESET% Enter / Drag-and-drop a different folder...
    echo.
    :prompt_multi_choice
    set "CHOICE="
    set /p "CHOICE=Select which folder to patch [1-!CUSTOM_OPT!] (Default: 1): "
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
if "!INPUT_DIR:~-1!"=="\" set "INPUT_DIR=!INPUT_DIR:~0,-1!"

REM If user dragged executable directly or another file
if /i "!INPUT_DIR:~-18!"=="Lethal Company.exe" (
    for %%F in ("!INPUT_DIR!") do set "INPUT_DIR=%%~dpF"
    if "!INPUT_DIR:~-1!"=="\" set "INPUT_DIR=!INPUT_DIR:~0,-1!"
)

REM 1. Check direct folder
if exist "!INPUT_DIR!\Lethal Company.exe" (
    set "GAME_DIR=!INPUT_DIR!"
    goto :game_dir_confirmed
)

REM 2. Check subfolder depth 1 (e.g. user dragged Downloads/Lethal Company)
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

REM 4. Check parent directories (in case user dragged BepInEx or Lethal Company_Data)
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
set "TEMP_DELETE_LIST=%TEMP%\lc_delete_list_%RANDOM%.txt"
set "TEMP_PATCH_ZIP=%TEMP%\lc_patch_%RANDOM%.zip"

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
