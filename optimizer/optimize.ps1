param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("Optimize", "Revert", "Check")]
    [string]$Mode = "Optimize",

    [Parameter(Mandatory = $false)]
    [string]$GameDir = ""
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $GameDir -or -not (Test-Path $GameDir)) {
    $GameDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not (Test-Path (Join-Path $GameDir "Lethal Company.exe"))) {
        $GameDir = (Get-Location).Path
    }
}

$configDir = Join-Path $GameDir "BepInEx\config"
$pluginsDir = Join-Path $GameDir "BepInEx\plugins"
$exePath = Join-Path $GameDir "Lethal Company.exe"

function Set-ConfigValue($file, $pattern, $replacement) {
    if (Test-Path $file) {
        $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
        }
    }
}

if ($Mode -eq "Optimize") {
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "           Applying Low-Spec Performance Optimizations (Network-Safe)       " -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1/7] Optimizing LCUltrawide resolution for low-spec rendering..." -ForegroundColor Cyan
    $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
    Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = 0.7"
    Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1.25"
    Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 1.777778"

    Write-Host "[2/7] Optimizing OpenBodyCams (Disabled 3D camera overhead)..." -ForegroundColor Cyan
    $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
    Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 80"
    Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 10"
    Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = false"
    Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = true"
    Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

    Write-Host "[3/7] Optimizing Terminal & Suits preview cameras..." -ForegroundColor Cyan
    $termStuff = Join-Path $configDir "darmuh.TerminalStuff.cfg"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionMirror\s*=.*$" "ObcResolutionMirror = 320; 240"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionBodyCam\s*=.*$" "ObcResolutionBodyCam = 320; 240"
    $suitsTerm = Join-Path $configDir "com.github.darmuh.suitsTerminal.cfg"
    Set-ConfigValue $suitsTerm "(?m)^OpenBodyCams Resolution\s*=.*$" "OpenBodyCams Resolution = 320; 240"

    Write-Host "[4/7] Capping ship security camera framerates (GeneralImprovements)..." -ForegroundColor Cyan
    $genImp = Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg"
    Set-ConfigValue $genImp "(?m)^ShipExternalCamFPS\s*=.*$" "ShipExternalCamFPS = 5"
    Set-ConfigValue $genImp "(?m)^ShipInternalCamFPS\s*=.*$" "ShipInternalCamFPS = 5"
    Set-ConfigValue $genImp "(?m)^AlwaysRenderMonitors\s*=.*$" "AlwaysRenderMonitors = false"

    Write-Host "[5/7] Optimizing ShipWindows exterior background rendering..." -ForegroundColor Cyan
    $shipWin = Join-Path $configDir "TestAccount666.ShipWindows.cfg"
    Set-ConfigValue $shipWin "(?m)^Skybox Type\s*=.*$" "Skybox Type = BLACK_AND_STARS"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Landing\s*=.*$" "Hide Moon Landing = true"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Transitions\s*=.*$" "Hide Moon Transitions = true"

    Write-Host "[6/7] Optimizing LethalSponge HDRP fog, shadows, and textures..." -ForegroundColor Cyan
    $sponge = Join-Path $configDir "LethalSponge.cfg"
    Set-ConfigValue $sponge "(?m)^securityCameraFramerate\s*=.*$" "securityCameraFramerate = 5"
    Set-ConfigValue $sponge "(?m)^shipCameraFramerate\s*=.*$" "shipCameraFramerate = 5"
    Set-ConfigValue $sponge "(?m)^mapCameraFramerate\s*=.*$" "mapCameraFramerate = 10"
    Set-ConfigValue $sponge "(?m)^shadowsMaxResolution\s*=.*$" "shadowsMaxResolution = 64"
    Set-ConfigValue $sponge "(?m)^shadowsAtlasSize\s*=.*$" "shadowsAtlasSize = 1024"
    Set-ConfigValue $sponge "(?m)^fogBudget\s*=.*$" "fogBudget = 0.05"
    Set-ConfigValue $sponge "(?m)^disableDOF\s*=.*$" "disableDOF = true"
    Set-ConfigValue $sponge "(?m)^disableShadows\s*=.*$" "disableShadows = false"
    Set-ConfigValue $sponge "(?m)^disableReflections\s*=.*$" "disableReflections = false"
    Set-ConfigValue $sponge "(?m)^disableBloom\s*=.*$" "disableBloom = true"
    Set-ConfigValue $sponge "(?m)^disableMotionBlur\s*=.*$" "disableMotionBlur = true"
    Set-ConfigValue $sponge "(?m)^maxCubeReflectionProbes\s*=.*$" "maxCubeReflectionProbes = 6"
    Set-ConfigValue $sponge "(?m)^maxPlanarReflectionProbes\s*=.*$" "maxPlanarReflectionProbes = 4"
    Set-ConfigValue $sponge "(?m)^unloadUnused\s*=.*$" "unloadUnused = false"
    Set-ConfigValue $sponge "(?m)^runDaily\s*=.*$" "runDaily = false"
    Set-ConfigValue $sponge "(?m)^deDupeMeshes\s*=.*$" "deDupeMeshes = false"
    Set-ConfigValue $sponge "(?m)^deDupeTextures\s*=.*$" "deDupeTextures = false"
    Set-ConfigValue $sponge "(?m)^deDupeAudio\s*=.*$" "deDupeAudio = false"
    Set-ConfigValue $sponge "(?m)^resizeTextures\s*=.*$" "resizeTextures = false"
    Set-ConfigValue $sponge "(?m)^maxResizeTextureSize\s*=.*$" "maxResizeTextureSize = 1024"

    Write-Host "[7/7] Verifying FPS Counter overlay plugin..." -ForegroundColor Cyan
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $localZip = Join-Path $scriptDir "optimizer_plugins.zip"
    $fpsDll = Join-Path $pluginsDir "LC_FPSCounter\LC_FPSCounter.dll"

    # Remove CullFactory if present (causes Netcode RPC signature mismatch with host)
    $cullFolder = Join-Path $pluginsDir "Zaggy1024-CullFactory"
    if (Test-Path $cullFolder) {
        Remove-Item -Recurse -Force $cullFolder -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $fpsDll)) {
        if (Test-Path $localZip) {
            Write-Host "Extracting optimizer_plugins.zip..." -ForegroundColor Yellow
            Expand-Archive -Path $localZip -DestinationPath $GameDir -Force
        }
        else {
            Write-Host "Downloading optimizer_plugins.zip from GitHub..." -ForegroundColor Yellow
            $tempZip = Join-Path $env:TEMP "lc_optimizer_plugins.zip"
            curl.exe -s -L -f -H "Cache-Control: no-cache" -H "Pragma: no-cache" "https://raw.githubusercontent.com/hayagerwin/lc-mods-patcher/main/optimizer/optimizer_plugins.zip" -o $tempZip
            if (Test-Path $tempZip) {
                Expand-Archive -Path $tempZip -DestinationPath $GameDir -Force
                Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
            }
        }
    }

    if (Test-Path $fpsDll) {
        Write-Host "FPS Counter is active (Press F8 in-game to toggle)." -ForegroundColor Green
    }
}
elseif ($Mode -eq "Revert") {
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "             Reverting to Standard Default Settings (High Specs)            " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[1/6] Reverting LCUltrawide resolution to Standard (1.0x)..." -ForegroundColor Yellow
    $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
    Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 0"

    Write-Host "[2/6] Reverting OpenBodyCams to Standard..." -ForegroundColor Yellow
    $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
    Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 160"
    Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 20"
    Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = true"
    Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = false"
    Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

    Write-Host "[3/6] Reverting Terminal & Suits preview camera resolutions..." -ForegroundColor Yellow
    $termStuff = Join-Path $configDir "darmuh.TerminalStuff.cfg"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionMirror\s*=.*$" "ObcResolutionMirror = 1000; 700"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionBodyCam\s*=.*$" "ObcResolutionBodyCam = 1000; 700"
    $suitsTerm = Join-Path $configDir "com.github.darmuh.suitsTerminal.cfg"
    Set-ConfigValue $suitsTerm "(?m)^OpenBodyCams Resolution\s*=.*$" "OpenBodyCams Resolution = 1000; 700"

    Write-Host "[4/6] Reverting GeneralImprovements camera framerates to Standard..." -ForegroundColor Yellow
    $genImp = Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg"
    Set-ConfigValue $genImp "(?m)^ShipExternalCamFPS\s*=.*$" "ShipExternalCamFPS = 10"
    Set-ConfigValue $genImp "(?m)^ShipInternalCamFPS\s*=.*$" "ShipInternalCamFPS = 10"
    Set-ConfigValue $genImp "(?m)^AlwaysRenderMonitors\s*=.*$" "AlwaysRenderMonitors = false"

    Write-Host "[5/6] Reverting ShipWindows exterior rendering to Standard..." -ForegroundColor Yellow
    $shipWin = Join-Path $configDir "TestAccount666.ShipWindows.cfg"
    Set-ConfigValue $shipWin "(?m)^Skybox Type\s*=.*$" "Skybox Type = REAL"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Landing\s*=.*$" "Hide Moon Landing = false"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Transitions\s*=.*$" "Hide Moon Transitions = false"

    Write-Host "[6/6] Reverting LethalSponge HDRP settings to Standard..." -ForegroundColor Yellow
    $sponge = Join-Path $configDir "LethalSponge.cfg"
    Set-ConfigValue $sponge "(?m)^securityCameraFramerate\s*=.*$" "securityCameraFramerate = 15"
    Set-ConfigValue $sponge "(?m)^shipCameraFramerate\s*=.*$" "shipCameraFramerate = 15"
    Set-ConfigValue $sponge "(?m)^mapCameraFramerate\s*=.*$" "mapCameraFramerate = 20"
    Set-ConfigValue $sponge "(?m)^shadowsMaxResolution\s*=.*$" "shadowsMaxResolution = 2048"
    Set-ConfigValue $sponge "(?m)^shadowsAtlasSize\s*=.*$" "shadowsAtlasSize = 4096"
    Set-ConfigValue $sponge "(?m)^fogBudget\s*=.*$" "fogBudget = 0.15"
    Set-ConfigValue $sponge "(?m)^disableDOF\s*=.*$" "disableDOF = false"
    Set-ConfigValue $sponge "(?m)^disableShadows\s*=.*$" "disableShadows = false"
    Set-ConfigValue $sponge "(?m)^disableReflections\s*=.*$" "disableReflections = false"
    Set-ConfigValue $sponge "(?m)^disableBloom\s*=.*$" "disableBloom = false"
    Set-ConfigValue $sponge "(?m)^disableMotionBlur\s*=.*$" "disableMotionBlur = false"
    Set-ConfigValue $sponge "(?m)^maxCubeReflectionProbes\s*=.*$" "maxCubeReflectionProbes = 12"
    Set-ConfigValue $sponge "(?m)^maxPlanarReflectionProbes\s*=.*$" "maxPlanarReflectionProbes = 8"
    Set-ConfigValue $sponge "(?m)^unloadUnused\s*=.*$" "unloadUnused = true"
    Set-ConfigValue $sponge "(?m)^runDaily\s*=.*$" "runDaily = true"
    Set-ConfigValue $sponge "(?m)^deDupeMeshes\s*=.*$" "deDupeMeshes = false"
    Set-ConfigValue $sponge "(?m)^deDupeTextures\s*=.*$" "deDupeTextures = false"
    Set-ConfigValue $sponge "(?m)^deDupeAudio\s*=.*$" "deDupeAudio = false"
    Set-ConfigValue $sponge "(?m)^resizeTextures\s*=.*$" "resizeTextures = false"
    Set-ConfigValue $sponge "(?m)^maxResizeTextureSize\s*=.*$" "maxResizeTextureSize = 2048"

    # Cleanup added FPS Counter plugin
    $fpsFolder = Join-Path $pluginsDir "LC_FPSCounter"
    if (Test-Path $fpsFolder) {
        Remove-Item -Recurse -Force $fpsFolder -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed LC_FPSCounter plugin" -ForegroundColor Yellow
    }
}
elseif ($Mode -eq "Check") {
    function Test-ConfigSetting($file, $pattern) {
        if (-not (Test-Path $file)) { return $false }
        $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
        return ($content -match $pattern)
    }

    $isLcOpt = Test-ConfigSetting (Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg") "(?m)^Gameplay Camera Resolution Multiplier\s*=\s*0\.7"
    $isObcOpt = Test-ConfigSetting (Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg") "(?m)^EnableCamera\s*=\s*false"
    $isCamFpsOpt = Test-ConfigSetting (Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg") "(?m)^ShipExternalCamFPS\s*=\s*5"
    $isWinOpt = Test-ConfigSetting (Join-Path $configDir "TestAccount666.ShipWindows.cfg") "(?m)^Skybox Type\s*=\s*BLACK_AND_STARS"
    $isSpongeOpt = Test-ConfigSetting (Join-Path $configDir "LethalSponge.cfg") "(?m)^shadowsMaxResolution\s*=\s*64"
    $isFpsOpt = Test-Path (Join-Path $pluginsDir "LC_FPSCounter\LC_FPSCounter.dll")

    function Format-CheckItem([string]$name, [bool]$isOpt, [string]$optDesc, [string]$vanillaDesc) {
        if ($isOpt) {
            Write-Host "   [" -NoNewline
            Write-Host ([char]0x221A) -ForegroundColor Green -NoNewline
            Write-Host "] " -NoNewline
            Write-Host ("{0,-18}" -f $name) -ForegroundColor White -NoNewline
            Write-Host ": " -NoNewline
            Write-Host $optDesc -ForegroundColor Green
        } else {
            Write-Host "   [" -NoNewline
            Write-Host "X" -ForegroundColor Red -NoNewline
            Write-Host "] " -NoNewline
            Write-Host ("{0,-18}" -f $name) -ForegroundColor DarkGray -NoNewline
            Write-Host ": " -NoNewline
            Write-Host $vanillaDesc -ForegroundColor Red
        }
    }

    Write-Host "  Optimization Feature Checklist:" -ForegroundColor Cyan
    Format-CheckItem -name "LCUltrawide" -isOpt $isLcOpt -optDesc "0.7x Resolution Scale and 16:9 Lock" -vanillaDesc "1.0x Full Native Resolution"
    Format-CheckItem -name "OpenBodyCams" -isOpt $isObcOpt -optDesc "3D Bodycam Rendering Disabled" -vanillaDesc "3D Camera Active (Heavy VRAM)"
    Format-CheckItem -name "Ship Cameras" -isOpt $isCamFpsOpt -optDesc "5 FPS Camera Refresh Cap" -vanillaDesc "10 FPS Camera Refresh Rate"
    Format-CheckItem -name "ShipWindows" -isOpt $isWinOpt -optDesc "Space Starfield and Shutters Active" -vanillaDesc "Real Skybox Active"
    Format-CheckItem -name "LethalSponge HDRP" -isOpt $isSpongeOpt -optDesc "64px Shadow Maps and 0.05 Fog Budget" -vanillaDesc "2048px Shadows and 0.15 Fog Budget"
    Format-CheckItem -name "FPS Counter" -isOpt $isFpsOpt -optDesc "Live In-Game Overlay Active (F8 Toggle)" -vanillaDesc "Plugin Not Installed"
}
