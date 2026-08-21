@echo off
setlocal EnableDelayedExpansion
title Lethal Company Mod Synchronizer

REM ============================================================================
REM REPOSITORY CONFIGURATION
REM Set your GitHub username, repository name, and branch below.
REM ============================================================================
set "REPO_USER=YourGitHubUsername"
set "REPO_NAME=YourModRepository"
set "BRANCH=main"

REM Ensure the script runs in its current folder
cd /d "%~dp0"

echo ============================================================================
echo                      Lethal Company Mod Synchronizer
echo ============================================================================
echo.

REM ----------------------------------------------------------------------------
REM 1. ENVIRONMENT CHECK
REM ----------------------------------------------------------------------------
if not exist "Lethal Company.exe" (
    goto :err_missing_game
)

REM Check for required native Windows utilities (curl.exe and tar.exe)
where curl.exe >nul 2>nul
if errorlevel 1 (
    goto :err_missing_curl
)

where tar.exe >nul 2>nul
if errorlevel 1 (
    goto :err_missing_tar
)

REM Setup remote URLs and temporary paths
set "DELETE_LIST_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/delete_list.txt"
set "PATCH_ZIP_URL=https://raw.githubusercontent.com/%REPO_USER%/%REPO_NAME%/%BRANCH%/patch.zip"
set "TEMP_DELETE_LIST=%TEMP%\lc_delete_list_%RANDOM%.txt"
set "TEMP_PATCH_ZIP=%TEMP%\lc_patch_%RANDOM%.zip"

REM ----------------------------------------------------------------------------
REM 2. STAGE 1: DELETE OBSOLETE FILES & FOLDERS
REM ----------------------------------------------------------------------------
echo [1/3] Checking for obsolete files and folders to remove...
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
            if exist "!NORM_PATH!\" (
                echo   [-] Removing folder: !NORM_PATH!
                rmdir /s /q "!NORM_PATH!" 2>nul
                set /a DELETED_COUNT+=1
            ) else if exist "!NORM_PATH!" (
                echo   [-] Removing file:   !NORM_PATH!
                del /f /q /a "!NORM_PATH!" 2>nul
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
REM 3. STAGE 2: DOWNLOAD MOD ARCHIVE
REM ----------------------------------------------------------------------------
echo [2/3] Downloading latest mod patch (patch.zip)...
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
REM 4. STAGE 3: EXTRACT MODS & OVERWRITE
REM ----------------------------------------------------------------------------
echo [3/3] Extracting mod files and updating game directory...
tar.exe -xf "%TEMP_PATCH_ZIP%" -C .

if errorlevel 1 (
    goto :err_extract_failed
)

REM Cleanup temporary archive
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul

echo.
echo ============================================================================
echo [SUCCESS] Lethal Company mods have been successfully synchronized.
echo ============================================================================
echo.
pause
exit /b 0


REM ============================================================================
REM ERROR HANDLERS
REM ============================================================================
:err_missing_game
echo [ERROR] "Lethal Company.exe" was not found in this folder.
echo.
echo Please make sure this script is placed inside your Lethal Company
echo game directory (e.g., steamapps\common\Lethal Company\).
echo.
pause
exit /b 1

:err_missing_curl
echo [ERROR] "curl.exe" was not found on your system.
echo Windows 10 (version 1803+) or Windows 11 is required for native sync.
echo.
pause
exit /b 1

:err_missing_tar
echo [ERROR] "tar.exe" was not found on your system.
echo Windows 10 (version 1803+) or Windows 11 is required for native sync.
echo.
pause
exit /b 1

:err_download_failed
echo.
echo [ERROR] Failed to download patch.zip from GitHub.
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
echo [ERROR] Downloaded patch.zip is empty (0 bytes).
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul
pause
exit /b 1

:err_extract_failed
echo.
echo [ERROR] Extraction failed. Ensure game files are not locked by a running instance of Lethal Company.
if exist "%TEMP_PATCH_ZIP%" del /f /q "%TEMP_PATCH_ZIP%" 2>nul
pause
exit /b 1
