@echo off
setlocal EnableDelayedExpansion
title Lethal Company Optimizer - Plugin Packager

for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "C_GREEN=%ESC%[92m"
set "C_CYAN=%ESC%[96m"
set "C_YELLOW=%ESC%[93m"
set "C_RESET=%ESC%[0m"

echo %C_CYAN%============================================================================
echo               Lethal Company Optimizer - Plugin Packager
echo ============================================================================%C_RESET%
echo.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$scriptDir = '%SCRIPT_DIR%';" ^
    "$sourceGame = 'c:\Games\Lethal Company';" ^
    "$zipPath = Join-Path $scriptDir 'optimizer_plugins.zip';" ^
    "$stagingDir = Join-Path $env:TEMP 'lc_opt_staging';" ^
    "if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir };" ^
    "New-Item -ItemType Directory -Force -Path (Join-Path $stagingDir 'BepInEx\plugins\LC_FPSCounter') | Out-Null;" ^
    "New-Item -ItemType Directory -Force -Path (Join-Path $stagingDir 'BepInEx\plugins\Zaggy1024-CullFactory') | Out-Null;" ^
    "$fpsSrc = Join-Path $sourceGame 'BepInEx\plugins\LC_FPSCounter\LC_FPSCounter.dll';" ^
    "$cullSrc = Join-Path $sourceGame 'BepInEx\plugins\Zaggy1024-CullFactory\CullFactory.dll';" ^
    "if (Test-Path $fpsSrc) { Copy-Item $fpsSrc -Destination (Join-Path $stagingDir 'BepInEx\plugins\LC_FPSCounter\LC_FPSCounter.dll') -Force; Write-Host '[+] Packaged LC_FPSCounter.dll' -ForegroundColor Green; };" ^
    "if (Test-Path $cullSrc) { Copy-Item $cullSrc -Destination (Join-Path $stagingDir 'BepInEx\plugins\Zaggy1024-CullFactory\CullFactory.dll') -Force; Write-Host '[+] Packaged CullFactory.dll' -ForegroundColor Green; };" ^
    "if (Test-Path $zipPath) { Remove-Item -Force $zipPath };" ^
    "Compress-Archive -Path (Join-Path $stagingDir 'BepInEx') -DestinationPath $zipPath -CompressionLevel Optimal;" ^
    "Remove-Item -Recurse -Force $stagingDir;" ^
    "Write-Host '[SUCCESS] Created optimizer_plugins.zip successfully!' -ForegroundColor Green;"

echo.
echo %C_GREEN%============================================================================
echo Ready to commit and push to GitHub!
echo ============================================================================%C_RESET%
echo.
pause
