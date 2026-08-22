@echo off
setlocal EnableDelayedExpansion
title Lethal Company Mod Synchronizer

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
echo                      Lethal Company Mod Synchronizer
echo ============================================================================%C_RESET%
echo.

REM ----------------------------------------------------------------------------
REM 0. SELF-UPDATE CHECK
REM ----------------------------------------------------------------------------
if not defined _SYNC_MODS_SELF_UPDATED (
    where curl.exe >nul 2>nul
    if not errorlevel 1 (
        set "SCRIPT_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/sync_mods.bat"
        set "TEMP_SCRIPT=%TEMP%\lc_sync_update_%RANDOM%.bat"

        curl.exe -s -L -f "!SCRIPT_URL!" -o "!TEMP_SCRIPT!" 2>nul
        if exist "!TEMP_SCRIPT!" (
            for %%F in ("!TEMP_SCRIPT!") do (
                if %%~zF gtr 0 (
                    fc.exe /b "%~f0" "!TEMP_SCRIPT!" >nul 2>nul
                    if errorlevel 1 (
                        echo %C_CYAN%[UPDATE]%C_RESET% A new version of sync_mods.bat was detected.
                        echo %C_CYAN%[UPDATE]%C_RESET% Updating script and restarting...
                        echo.
                        set "_SYNC_MODS_SELF_UPDATED=1"
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

REM Check 1: Current script folder
if exist "%SCRIPT_DIR%Lethal Company.exe" (
    set "GAME_DIR=%SCRIPT_DIR%"
)

REM Check 2: Local config file in script directory
if not defined GAME_DIR (
    if exist "%SCRIPT_DIR%lc_game_path.txt" (
        set /p SAVED_PATH=<"%SCRIPT_DIR%lc_game_path.txt"
        if defined SAVED_PATH (
            set "SAVED_PATH=!SAVED_PATH:"=!"
            if exist "!SAVED_PATH!\Lethal Company.exe" (
                set "GAME_DIR=!SAVED_PATH!"
            )
        )
    )
)

REM Check 3: Global AppData saved config
if not defined GAME_DIR (
    if exist "%CONFIG_FILE%" (
        set /p SAVED_PATH=<"%CONFIG_FILE%"
        if defined SAVED_PATH (
            set "SAVED_PATH=!SAVED_PATH:"=!"
            if exist "!SAVED_PATH!\Lethal Company.exe" (
                set "GAME_DIR=!SAVED_PATH!"
            )
        )
    )
)

REM Check 4: Common installation directories (Online-Fix, repacks, Steam)
if not defined GAME_DIR (
    for %%P in (
        "C:\Games\Lethal Company"
        "D:\Games\Lethal Company"
        "E:\Games\Lethal Company"
        "F:\Games\Lethal Company"
        "%USERPROFILE%\Downloads\Lethal Company"
        "%USERPROFILE%\Desktop\Lethal Company"
        "%ProgramFiles(x86)%\Steam\steamapps\common\Lethal Company"
        "%ProgramFiles%\Steam\steamapps\common\Lethal Company"
        "C:\Program Files\Steam\steamapps\common\Lethal Company"
        "D:\SteamLibrary\steamapps\common\Lethal Company"
        "E:\SteamLibrary\steamapps\common\Lethal Company"
        "F:\SteamLibrary\steamapps\common\Lethal Company"
    ) do (
        if not defined GAME_DIR (
            if exist "%%~P\Lethal Company.exe" (
                set "GAME_DIR=%%~P"
            )
        )
    )
)

REM Check 5: Wildcard match in Downloads and Desktop folders
if not defined GAME_DIR (
    for /d %%D in ("%USERPROFILE%\Downloads\Lethal*") do (
        if not defined GAME_DIR (
            if exist "%%~fD\Lethal Company.exe" (
                set "GAME_DIR=%%~fD"
            )
        )
    )
)

if not defined GAME_DIR (
    for /d %%D in ("%USERPROFILE%\Desktop\Lethal*") do (
        if not defined GAME_DIR (
            if exist "%%~fD\Lethal Company.exe" (
                set "GAME_DIR=%%~fD"
            )
        )
    )
)

REM Check 6: Interactive Prompt if not automatically located
:prompt_game_path
if not defined GAME_DIR (
    echo %C_YELLOW%[!] Lethal Company folder was not automatically detected.%C_RESET%
    echo.
    echo Please enter or drag-and-drop your Lethal Company game folder
    echo ^(where "Lethal Company.exe" is located, e.g. C:\Games\Lethal Company^):
    echo.
    set /p "INPUT_DIR=> "
    if not defined INPUT_DIR (
        goto :err_missing_game
    )
    set "INPUT_DIR=!INPUT_DIR:"=!"
    REM If user dragged the executable directly, get parent folder
    if /i "!INPUT_DIR:~-18!"=="Lethal Company.exe" (
        for %%F in ("!INPUT_DIR!") do set "INPUT_DIR=%%~dpF"
    )
    REM Strip trailing backslash
    if "!INPUT_DIR:~-1!"=="\" set "INPUT_DIR=!INPUT_DIR:~0,-1!"

    if exist "!INPUT_DIR!\Lethal Company.exe" (
        set "GAME_DIR=!INPUT_DIR!"
    ) else (
        echo.
        echo %C_RED%[ERROR] "Lethal Company.exe" was not found in: "!INPUT_DIR!"%C_RESET%
        echo.
        goto :prompt_game_path
    )
)

REM Strip trailing backslash from GAME_DIR if present
if "!GAME_DIR:~-1!"=="\" set "GAME_DIR=!GAME_DIR:~0,-1!"

REM Save game path to config for future one-click runs
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" 2>nul
echo !GAME_DIR!>"%CONFIG_FILE%" 2>nul

echo %C_GREEN%[+] Target Game Directory:%C_RESET% !GAME_DIR!
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
echo Launching Lethal Company...
cd /d "!GAME_DIR!"
start "" "Lethal Company.exe"
exit /b 0


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
