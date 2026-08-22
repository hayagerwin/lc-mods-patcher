param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("Optimize", "Revert")]
    [string]$Mode = "Optimize",

    [Parameter(Mandatory = $false)]
    [string]$GameDir = ""
)

$ErrorActionPreference = "SilentlyContinue"

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
    Write-Host "           Applying Low-Spec Performance Optimizations (Intel UHD)          " -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1/10] Locking Windows GPU Preference to Intel UHD..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name $exePath -Value "GpuPreference=1;" -Force -ErrorAction SilentlyContinue

    Write-Host "[2/10] Optimizing LCUltrawide resolution for Intel UHD..." -ForegroundColor Cyan
    $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
    Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = 0.7"
    Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1.25"
    Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 1.777778"

    Write-Host "[3/10] Optimizing OpenBodyCams (Disabled 3D camera overhead)..." -ForegroundColor Cyan
    $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
    Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 80"
    Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 10"
    Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = false"
    Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = true"
    Set-ConfigValue $obc "(?m)^GeneralImprovementsBetterMonitorIndex\s*=.*$" "GeneralImprovementsBetterMonitorIndex = 14"
    Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

    Write-Host "[4/10] Optimizing Terminal & Suits preview cameras..." -ForegroundColor Cyan
    $termStuff = Join-Path $configDir "darmuh.TerminalStuff.cfg"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionMirror\s*=.*$" "ObcResolutionMirror = 320; 240"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionBodyCam\s*=.*$" "ObcResolutionBodyCam = 320; 240"
    $suitsTerm = Join-Path $configDir "com.github.darmuh.suitsTerminal.cfg"
    Set-ConfigValue $suitsTerm "(?m)^OpenBodyCams Resolution\s*=.*$" "OpenBodyCams Resolution = 320; 240"

    Write-Host "[5/10] Optimizing GeneralImprovements ship monitors..." -ForegroundColor Cyan
    $genImp = Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg"
    Set-ConfigValue $genImp "(?m)^ShipExternalCamFPS\s*=.*$" "ShipExternalCamFPS = 5"
    Set-ConfigValue $genImp "(?m)^ShipInternalCamFPS\s*=.*$" "ShipInternalCamFPS = 5"
    Set-ConfigValue $genImp "(?m)^AddMoreBetterMonitors\s*=.*$" "AddMoreBetterMonitors = false"
    Set-ConfigValue $genImp "(?m)^ShipMonitor1\s*=.*$" "ShipMonitor1 = ScrapLeft"
    Set-ConfigValue $genImp "(?m)^ShipMonitor2\s*=.*$" "ShipMonitor2 = ShipScrap"
    Set-ConfigValue $genImp "(?m)^ShipMonitor3\s*=.*$" "ShipMonitor3 = ProfitQuota"
    Set-ConfigValue $genImp "(?m)^ShipMonitor4\s*=.*$" "ShipMonitor4 = Deadline"
    Set-ConfigValue $genImp "(?m)^ShipMonitor5\s*=.*$" "ShipMonitor5 = Credits"
    Set-ConfigValue $genImp "(?m)^ShipMonitor6\s*=.*$" "ShipMonitor6 = CompanyBuyRate"
    Set-ConfigValue $genImp "(?m)^ShipMonitor7\s*=.*$" "ShipMonitor7 = PlayersAlive"
    Set-ConfigValue $genImp "(?m)^ShipMonitor8\s*=.*$" "ShipMonitor8 = Sales"
    Set-ConfigValue $genImp "(?m)^ShipMonitor9\s*=.*$" "ShipMonitor9 = PlayerHealthExact"
    Set-ConfigValue $genImp "(?m)^ShipMonitor10\s*=.*$" "ShipMonitor10 = None"
    Set-ConfigValue $genImp "(?m)^ShipMonitor11\s*=.*$" "ShipMonitor11 = None"
    Set-ConfigValue $genImp "(?m)^ShipMonitor12\s*=.*$" "ShipMonitor12 = None"
    Set-ConfigValue $genImp "(?m)^ShipMonitor13\s*=.*$" "ShipMonitor13 = None"
    Set-ConfigValue $genImp "(?m)^ShipMonitor14\s*=.*$" "ShipMonitor14 = None"

    Write-Host "[6/10] Disabling ScienceBird rotating floodlight on ship..." -ForegroundColor Cyan
    $sbTweaks = Join-Path $configDir "ScienceBird.ScienceBirdTweaks.cfg"
    Set-ConfigValue $sbTweaks "(?m)^Rotating Floodlight\s*=.*$" "Rotating Floodlight = false"
    Set-ConfigValue $sbTweaks "(?m)^Rotate Floodlight Upon Landing\s*=.*$" "Rotate Floodlight Upon Landing = false"
    Set-ConfigValue $sbTweaks "(?m)^Fancy Button Panel\s*=.*$" "Fancy Button Panel = false"
    Set-ConfigValue $sbTweaks "(?m)^Ship Floodlight Range\s*=.*$" "Ship Floodlight Range = 30"
    Set-ConfigValue $sbTweaks "(?m)^Ship Floodlight Intensity in Lumen\s*=.*$" "Ship Floodlight Intensity in Lumen = 2275"

    Write-Host "[7/10] Optimizing ShipWindows exterior rendering..." -ForegroundColor Cyan
    $shipWin = Join-Path $configDir "TestAccount666.ShipWindows.cfg"
    Set-ConfigValue $shipWin "(?m)^Skybox Type\s*=.*$" "Skybox Type = BLACK_AND_STARS"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Landing\s*=.*$" "Hide Moon Landing = true"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Transitions\s*=.*$" "Hide Moon Transitions = true"
    Set-ConfigValue $shipWin "(?m)^5\.\s*Spawn Underlights\s*=.*$" "5. Spawn Underlights = false"

    Write-Host "[8/10] Optimizing LethalSponge HDRP fog, shadows, and textures..." -ForegroundColor Cyan
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

    Write-Host "[9/10] Verifying low-spec plugins (CullFactory & FPS Counter)..." -ForegroundColor Cyan
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $localZip = Join-Path $scriptDir "optimizer_plugins.zip"
    $cullDll = Join-Path $pluginsDir "Zaggy1024-CullFactory\CullFactory.dll"
    $fpsDll = Join-Path $pluginsDir "LC_FPSCounter\LC_FPSCounter.dll"

    if (-not (Test-Path $cullDll) -or -not (Test-Path $fpsDll)) {
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

    Write-Host "[10/10] Verifying FPS Counter plugin status..." -ForegroundColor Cyan
    if (Test-Path $fpsDll) {
        Write-Host "FPS Counter is active (Press F8 in-game to toggle)." -ForegroundColor Green
    }
}
elseif ($Mode -eq "Revert") {
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "             Reverting to Standard Default Settings (High Specs)            " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[1/8] Reverting Windows GPU Preference to Default..." -ForegroundColor Yellow
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name $exePath -ErrorAction SilentlyContinue

    Write-Host "[2/8] Reverting LCUltrawide resolution to Standard (1.0x)..." -ForegroundColor Yellow
    $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
    Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 0"

    Write-Host "[3/8] Reverting OpenBodyCams to Standard..." -ForegroundColor Yellow
    $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
    Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 160"
    Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 20"
    Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = true"
    Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = false"
    Set-ConfigValue $obc "(?m)^GeneralImprovementsBetterMonitorIndex\s*=.*$" "GeneralImprovementsBetterMonitorIndex = 0"
    Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

    Write-Host "[4/8] Reverting Terminal & Suits preview camera resolutions..." -ForegroundColor Yellow
    $termStuff = Join-Path $configDir "darmuh.TerminalStuff.cfg"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionMirror\s*=.*$" "ObcResolutionMirror = 1000; 700"
    Set-ConfigValue $termStuff "(?m)^ObcResolutionBodyCam\s*=.*$" "ObcResolutionBodyCam = 1000; 700"
    $suitsTerm = Join-Path $configDir "com.github.darmuh.suitsTerminal.cfg"
    Set-ConfigValue $suitsTerm "(?m)^OpenBodyCams Resolution\s*=.*$" "OpenBodyCams Resolution = 1000; 700"

    Write-Host "[5/8] Reverting GeneralImprovements ship monitors to Standard..." -ForegroundColor Yellow
    $genImp = Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg"
    Set-ConfigValue $genImp "(?m)^ShipExternalCamFPS\s*=.*$" "ShipExternalCamFPS = 10"
    Set-ConfigValue $genImp "(?m)^ShipInternalCamFPS\s*=.*$" "ShipInternalCamFPS = 10"
    Set-ConfigValue $genImp "(?m)^AddMoreBetterMonitors\s*=.*$" "AddMoreBetterMonitors = true"
    Set-ConfigValue $genImp "(?m)^ShipMonitor1\s*=.*$" "ShipMonitor1 = FancyWeather"
    Set-ConfigValue $genImp "(?m)^ShipMonitor2\s*=.*$" "ShipMonitor2 = DangerLevel"
    Set-ConfigValue $genImp "(?m)^ShipMonitor3\s*=.*$" "ShipMonitor3 = Time"
    Set-ConfigValue $genImp "(?m)^ShipMonitor4\s*=.*$" "ShipMonitor4 = Deadline"
    Set-ConfigValue $genImp "(?m)^ShipMonitor5\s*=.*$" "ShipMonitor5 = ProfitQuota"
    Set-ConfigValue $genImp "(?m)^ShipMonitor6\s*=.*$" "ShipMonitor6 = DoorPower"
    Set-ConfigValue $genImp "(?m)^ShipMonitor7\s*=.*$" "ShipMonitor7 = PlayersAlive"
    Set-ConfigValue $genImp "(?m)^ShipMonitor8\s*=.*$" "ShipMonitor8 = Sales"
    Set-ConfigValue $genImp "(?m)^ShipMonitor9\s*=.*$" "ShipMonitor9 = ScrapLeft"
    Set-ConfigValue $genImp "(?m)^ShipMonitor10\s*=.*$" "ShipMonitor10 = ShipScrap"
    Set-ConfigValue $genImp "(?m)^ShipMonitor11\s*=.*$" "ShipMonitor11 = TotalDays"
    Set-ConfigValue $genImp "(?m)^ShipMonitor12\s*=.*$" "ShipMonitor12 = ExternalCam"
    Set-ConfigValue $genImp "(?m)^ShipMonitor13\s*=.*$" "ShipMonitor13 = PlayerHealthExact"
    Set-ConfigValue $genImp "(?m)^ShipMonitor14\s*=.*$" "ShipMonitor14 = None"

    Write-Host "[6/8] Reverting ScienceBird floodlight to Standard..." -ForegroundColor Yellow
    $sbTweaks = Join-Path $configDir "ScienceBird.ScienceBirdTweaks.cfg"
    Set-ConfigValue $sbTweaks "(?m)^Rotating Floodlight\s*=.*$" "Rotating Floodlight = true"
    Set-ConfigValue $sbTweaks "(?m)^Rotate Floodlight Upon Landing\s*=.*$" "Rotate Floodlight Upon Landing = true"
    Set-ConfigValue $sbTweaks "(?m)^Fancy Button Panel\s*=.*$" "Fancy Button Panel = true"
    Set-ConfigValue $sbTweaks "(?m)^Ship Floodlight Range\s*=.*$" "Ship Floodlight Range = 45"
    Set-ConfigValue $sbTweaks "(?m)^Ship Floodlight Intensity in Lumen\s*=.*$" "Ship Floodlight Intensity in Lumen = 760"

    Write-Host "[7/8] Reverting ShipWindows exterior rendering to Standard..." -ForegroundColor Yellow
    $shipWin = Join-Path $configDir "TestAccount666.ShipWindows.cfg"
    Set-ConfigValue $shipWin "(?m)^Skybox Type\s*=.*$" "Skybox Type = REAL"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Landing\s*=.*$" "Hide Moon Landing = false"
    Set-ConfigValue $shipWin "(?m)^Hide Moon Transitions\s*=.*$" "Hide Moon Transitions = false"
    Set-ConfigValue $shipWin "(?m)^5\.\s*Spawn Underlights\s*=.*$" "5. Spawn Underlights = true"

    Write-Host "[8/8] Reverting LethalSponge HDRP settings to Standard..." -ForegroundColor Yellow
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

    Write-Host "[9/9] Cleaning up added optimization plugins (CullFactory & FPS Counter)..." -ForegroundColor Yellow
    $fpsFolder = Join-Path $pluginsDir "LC_FPSCounter"
    $cullFolder = Join-Path $pluginsDir "Zaggy1024-CullFactory"
    if (Test-Path $fpsFolder) {
        Remove-Item -Recurse -Force $fpsFolder -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed LC_FPSCounter plugin" -ForegroundColor Yellow
    }
    if (Test-Path $cullFolder) {
        Remove-Item -Recurse -Force $cullFolder -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed CullFactory plugin" -ForegroundColor Yellow
    }
}
