param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("Optimize", "Revert", "Check", "Custom", "LogMinimal", "LogDebug", "LogSilent", "LogCheck", "LogClear")]
    [string]$Mode = "Optimize",

    [Parameter(Mandatory = $false)]
    [string]$GameDir = "",

    [Parameter(Mandatory = $false)]
    [string]$ResolutionScale = "0.7",

    [Parameter(Mandatory = $false)]
    [string]$OptBodyCam = "yes",

    [Parameter(Mandatory = $false)]
    [string]$OptShipCameras = "yes",

    [Parameter(Mandatory = $false)]
    [string]$OptShipWindows = "yes",

    [Parameter(Mandatory = $false)]
    [string]$OptHDRP = "yes",

    [Parameter(Mandatory = $false)]
    [string]$OptFPSCounter = "yes"
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

function Set-IniSectionValue($file, $section, $key, $value) {
    if (-not (Test-Path $file)) { return }
    $lines = [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)
    $inSection = $false
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.*?)\]') {
            if ($matches[1].Trim() -eq $section) {
                $inSection = $true
            } else {
                $inSection = $false
            }
        }
        if ($inSection -and $line -match "^\s*$([regex]::Escape($key))\s*=") {
            $newLines += "$key = $value"
        } else {
            $newLines += $line
        }
    }
    [System.IO.File]::WriteAllLines($file, $newLines, [System.Text.Encoding]::UTF8)
}

function Get-IniSectionValue($file, $section, $key) {
    if (-not (Test-Path $file)) { return $null }
    $lines = [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.*?)\]') {
            if ($matches[1].Trim() -eq $section) {
                $inSection = $true
            } else {
                $inSection = $false
            }
        }
        if ($inSection -and $line -match "^\s*$([regex]::Escape($key))\s*=\s*(.*)$") {
            return $matches[1].Trim()
        }
    }
    return $null
}

if ($Mode -eq "Optimize" -or $Mode -eq "Custom") {
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "           Applying Low-Spec Performance Optimizations (Network-Safe)       " -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. Resolution
    if ($ResolutionScale) {
        Write-Host "[1/6] Applying resolution scale ($($ResolutionScale)x) in LCUltrawide..." -ForegroundColor Cyan
        $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
        Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = $ResolutionScale"
        Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1.25"
        Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 1.777778"
    }

    # 2. BodyCam
    if ($OptBodyCam -eq "yes") {
        Write-Host "[2/6] Optimizing OpenBodyCams (Disabling heavy 3D camera overhead)..." -ForegroundColor Cyan
        $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
        Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 80"
        Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 10"
        Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = false"
        Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = true"
        Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

        $termStuff = Join-Path $configDir "darmuh.TerminalStuff.cfg"
        Set-ConfigValue $termStuff "(?m)^ObcResolutionMirror\s*=.*$" "ObcResolutionMirror = 320; 240"
        Set-ConfigValue $termStuff "(?m)^ObcResolutionBodyCam\s*=.*$" "ObcResolutionBodyCam = 320; 240"
        $suitsTerm = Join-Path $configDir "com.github.darmuh.suitsTerminal.cfg"
        Set-ConfigValue $suitsTerm "(?m)^OpenBodyCams Resolution\s*=.*$" "OpenBodyCams Resolution = 320; 240"
    }

    # 3. Ship Cameras
    if ($OptShipCameras -eq "yes") {
        Write-Host "[3/6] Capping ship security camera framerates (GeneralImprovements)..." -ForegroundColor Cyan
        $genImp = Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg"
        Set-ConfigValue $genImp "(?m)^ShipExternalCamFPS\s*=.*$" "ShipExternalCamFPS = 5"
        Set-ConfigValue $genImp "(?m)^ShipInternalCamFPS\s*=.*$" "ShipInternalCamFPS = 5"
        Set-ConfigValue $genImp "(?m)^AlwaysRenderMonitors\s*=.*$" "AlwaysRenderMonitors = false"
    }

    # 4. ShipWindows
    if ($OptShipWindows -eq "yes") {
        Write-Host "[4/6] Optimizing ShipWindows exterior background rendering..." -ForegroundColor Cyan
        $shipWin = Join-Path $configDir "TestAccount666.ShipWindows.cfg"
        Set-ConfigValue $shipWin "(?m)^Skybox Type\s*=.*$" "Skybox Type = BLACK_AND_STARS"
        Set-ConfigValue $shipWin "(?m)^Hide Moon Landing\s*=.*$" "Hide Moon Landing = true"
        Set-ConfigValue $shipWin "(?m)^Hide Moon Transitions\s*=.*$" "Hide Moon Transitions = true"
    }

    # 5. HDRP / LethalSponge
    if ($OptHDRP -eq "yes") {
        Write-Host "[5/6] Optimizing LethalSponge HDRP fog, shadows, and textures..." -ForegroundColor Cyan
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
    }

    # 6. FPS Counter
    if ($OptFPSCounter -eq "yes") {
        Write-Host "[6/6] Verifying FPS Counter overlay plugin..." -ForegroundColor Cyan
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $localZip = Join-Path $scriptDir "optimizer_plugins.zip"
        $fpsDll = Join-Path $pluginsDir "LC_FPSCounter\LC_FPSCounter.dll"

        if (-not (Test-Path $fpsDll) -and (Test-Path $localZip)) {
            Expand-Archive -Path $localZip -DestinationPath $GameDir -Force -ErrorAction SilentlyContinue
        }
    }
}
elseif ($Mode -eq "Revert") {
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "         Reverting Performance Optimizations to Standard Defaults           " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[1/6] Reverting LCUltrawide resolution to Standard (1.0x Native)..." -ForegroundColor Yellow
    $lcUltra = Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg"
    Set-ConfigValue $lcUltra "(?m)^Gameplay Camera Resolution Multiplier\s*=.*$" "Gameplay Camera Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^Terminal Resolution Multiplier\s*=.*$" "Terminal Resolution Multiplier = 1"
    Set-ConfigValue $lcUltra "(?m)^AspectRatio\s*=.*$" "AspectRatio = 0"

    Write-Host "[2/6] Reverting OpenBodyCams to Standard 3D Camera..." -ForegroundColor Yellow
    $obc = Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg"
    Set-ConfigValue $obc "(?m)^HorizontalResolution\s*=.*$" "HorizontalResolution = 160"
    Set-ConfigValue $obc "(?m)^Framerate\s*=.*$" "Framerate = 20"
    Set-ConfigValue $obc "(?m)^EnableCamera\s*=.*$" "EnableCamera = true"
    Set-ConfigValue $obc "(?m)^DisplayOriginalScreenWhenDisabled\s*=.*$" "DisplayOriginalScreenWhenDisabled = true"
    Set-ConfigValue $obc "(?m)^EnablePiPBodyCam\s*=.*$" "EnablePiPBodyCam = false"

    Write-Host "[3/6] Reverting Terminal & Suits cameras to Standard..." -ForegroundColor Yellow
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

    function Get-ConfigValue($file, $pattern) {
        if (-not (Test-Path $file)) { return $null }
        $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
        if ($content -match $pattern) {
            return $matches[1].Trim()
        }
        return $null
    }

    $currentScale = Get-ConfigValue (Join-Path $configDir "com.github.lethalcompanymodding.LCUltrawide.cfg") "(?m)^Gameplay Camera Resolution Multiplier\s*=\s*(.*)$"
    if (-not $currentScale) { $currentScale = "1.0" }

    $isLcOpt = ($currentScale -ne "1" -and $currentScale -ne "1.0" -and $currentScale -ne "1.2")
    $scaleDesc = "$($currentScale)x Res Scale"
    if ($currentScale -eq "0.5") { $scaleGain = "+45-60%" }
    elseif ($currentScale -eq "0.7") { $scaleGain = "+25-35%" }
    elseif ($currentScale -eq "1.2") { $scaleGain = "-15-20% (Crisp)"; $scaleDesc = "1.2x High Res" }
    else { $scaleGain = "Baseline"; $scaleDesc = "1.0x Native Res" }

    $isObcOpt = Test-ConfigSetting (Join-Path $configDir "Zaggy1024.OpenBodyCams.cfg") "(?m)^EnableCamera\s*=\s*false"
    $isCamFpsOpt = Test-ConfigSetting (Join-Path $configDir "ShaosilGaming.GeneralImprovements.cfg") "(?m)^ShipExternalCamFPS\s*=\s*5"
    $isWinOpt = Test-ConfigSetting (Join-Path $configDir "TestAccount666.ShipWindows.cfg") "(?m)^Skybox Type\s*=\s*BLACK_AND_STARS"
    $isSpongeOpt = Test-ConfigSetting (Join-Path $configDir "LethalSponge.cfg") "(?m)^shadowsMaxResolution\s*=\s*64"
    $isFpsOpt = Test-Path (Join-Path $pluginsDir "LC_FPSCounter\LC_FPSCounter.dll")

    function Format-CheckItem([string]$name, [bool]$isOpt, [string]$optDesc, [string]$vanillaDesc, [string]$impact) {
        if ($isOpt) {
            Write-Host "   [" -NoNewline
            Write-Host ([char]0x221A) -ForegroundColor Green -NoNewline
            Write-Host "] " -NoNewline
            Write-Host ("{0,-16}" -f $name) -ForegroundColor White -NoNewline
            Write-Host ": " -NoNewline
            Write-Host ("{0,-36}" -f $optDesc) -ForegroundColor Green -NoNewline
            Write-Host (" [" + $impact + " FPS]") -ForegroundColor Cyan
        } else {
            Write-Host "   [" -NoNewline
            Write-Host "X" -ForegroundColor Red -NoNewline
            Write-Host "] " -NoNewline
            Write-Host ("{0,-16}" -f $name) -ForegroundColor DarkGray -NoNewline
            Write-Host ": " -NoNewline
            Write-Host ("{0,-36}" -f $vanillaDesc) -ForegroundColor DarkGray -NoNewline
            Write-Host (" [" + $impact + " Available]") -ForegroundColor DarkYellow
        }
    }

    Write-Host "  Optimization Feature Checklist & Estimated FPS Impact:" -ForegroundColor Cyan
    Format-CheckItem -name "Resolution" -isOpt $isLcOpt -optDesc $scaleDesc -vanillaDesc $scaleDesc -impact $scaleGain
    Format-CheckItem -name "OpenBodyCams" -isOpt $isObcOpt -optDesc "3D Bodycam Rendering Disabled" -vanillaDesc "3D Camera Active (Heavy VRAM)" -impact "+15-20%"
    Format-CheckItem -name "Ship Cameras" -isOpt $isCamFpsOpt -optDesc "5 FPS Camera Refresh Cap" -vanillaDesc "10 FPS Camera Refresh Rate" -impact "+8-12%"
    Format-CheckItem -name "ShipWindows" -isOpt $isWinOpt -optDesc "Space Starfield Skybox Active" -vanillaDesc "Real 3D Exterior Skybox" -impact "+10-15%"
    Format-CheckItem -name "LethalSponge" -isOpt $isSpongeOpt -optDesc "64px Shadows & 0.05 Fog Budget" -vanillaDesc "2048px Shadows & 0.15 Fog" -impact "+12-18%"
    Format-CheckItem -name "FPS Counter" -isOpt $isFpsOpt -optDesc "Live Overlay Active (F8 Toggle)" -vanillaDesc "Plugin Not Installed" -impact "Diagnostic"
}
elseif ($Mode -eq "LogMinimal") {
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "      Configuring Clean Console & High-Performance Logging Mode             " -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
    $bepCfg = Join-Path $configDir "BepInEx.cfg"
    if (Test-Path $bepCfg) {
        Write-Host "  [1/4] Keeping BepInEx console terminal window active for visual loading..." -ForegroundColor Cyan
        Set-IniSectionValue $bepCfg "Logging.Console" "Enabled" "true"
        Set-IniSectionValue $bepCfg "Logging.Console" "LogLevels" "Fatal, Error, Warning, Message, Info"

        Write-Host "  [2/4] Disabling Unity engine log redirection (Eliminates in-game lock lag)..." -ForegroundColor Cyan
        Set-IniSectionValue $bepCfg "Logging" "UnityLogListening" "false"
        Set-IniSectionValue $bepCfg "Logging.Disk" "WriteUnityLog" "false"

        Write-Host "  [3/4] Capping disk log levels to Errors & Warnings only..." -ForegroundColor Cyan
        Set-IniSectionValue $bepCfg "Logging.Disk" "LogLevels" "Fatal, Error, Warning"
        Set-IniSectionValue $bepCfg "Logging.Disk" "Enabled" "true"

        Write-Host "  [4/4] Setting Harmony log channels to Standard..." -ForegroundColor Cyan
        Set-IniSectionValue $bepCfg "Harmony.Logger" "LogChannels" "Warn, Error"
        Write-Host ""
        Write-Host "  [SUCCESS] Clean Console & High Performance Mode configured!" -ForegroundColor Green
        Write-Host "            (Loading progress visible on startup, zero lag during gameplay)" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] BepInEx.cfg was not found in $configDir" -ForegroundColor Red
    }
}
elseif ($Mode -eq "LogDebug") {
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "             Configuring Full Verbose Debug Logging Mode                    " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""
    $bepCfg = Join-Path $configDir "BepInEx.cfg"
    if (Test-Path $bepCfg) {
        Write-Host "  [1/4] Enabling BepInEx console terminal window with ALL log levels..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging.Console" "Enabled" "true"
        Set-IniSectionValue $bepCfg "Logging.Console" "LogLevels" "All"

        Write-Host "  [2/4] Enabling full Unity engine log redirection..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging" "UnityLogListening" "true"
        Set-IniSectionValue $bepCfg "Logging.Disk" "WriteUnityLog" "true"

        Write-Host "  [3/4] Setting disk log levels to ALL (Verbose debugging)..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging.Disk" "LogLevels" "All"
        Set-IniSectionValue $bepCfg "Logging.Disk" "Enabled" "true"

        Write-Host "  [4/4] Setting Harmony log channels to Debug & All..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Harmony.Logger" "LogChannels" "Warn, Error, Debug, All"
        Write-Host ""
        Write-Host "  [SUCCESS] Full Debug logging configured! (All raw debug logs recorded)" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] BepInEx.cfg was not found in $configDir" -ForegroundColor Red
    }
}
elseif ($Mode -eq "LogSilent") {
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host "              Configuring Silent Background Mode (Console Hidden)           " -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Yellow
    Write-Host ""
    $bepCfg = Join-Path $configDir "BepInEx.cfg"
    if (Test-Path $bepCfg) {
        Write-Host "  [1/3] Hiding BepInEx console terminal window..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging.Console" "Enabled" "false"
        Set-IniSectionValue $bepCfg "Logging.Console" "LogLevels" "Fatal, Error, Warning"

        Write-Host "  [2/3] Disabling Unity engine log redirection..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging" "UnityLogListening" "false"
        Set-IniSectionValue $bepCfg "Logging.Disk" "WriteUnityLog" "false"

        Write-Host "  [3/3] Setting disk log levels to Errors & Warnings only..." -ForegroundColor Yellow
        Set-IniSectionValue $bepCfg "Logging.Disk" "LogLevels" "Fatal, Error, Warning"
        Set-IniSectionValue $bepCfg "Logging.Disk" "Enabled" "true"
        Write-Host ""
        Write-Host "  [SUCCESS] Silent background mode configured (Console window hidden)." -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] BepInEx.cfg was not found in $configDir" -ForegroundColor Red
    }
}
elseif ($Mode -eq "LogCheck") {
    $bepCfg = Join-Path $configDir "BepInEx.cfg"
    $conEnabled = Get-IniSectionValue $bepCfg "Logging.Console" "Enabled"
    $conLevels = Get-IniSectionValue $bepCfg "Logging.Console" "LogLevels"
    $diskUnity = Get-IniSectionValue $bepCfg "Logging.Disk" "WriteUnityLog"
    $diskLevels = Get-IniSectionValue $bepCfg "Logging.Disk" "LogLevels"

    $logFile = Join-Path $GameDir "BepInEx\LogOutput.log"
    $logSizeStr = "0 KB"
    if (Test-Path $logFile) {
        $sizeBytes = (Get-Item $logFile).Length
        if ($sizeBytes -gt 1MB) {
            $logSizeStr = ("{0:N2} MB" -f ($sizeBytes / 1MB))
        } else {
            $logSizeStr = ("{0:N0} KB" -f ($sizeBytes / 1KB))
        }
    }

    Write-Host "  Logging & Diagnostic Configuration Status:" -ForegroundColor Cyan
    if ($conEnabled -eq "true" -and $conLevels -ne "All") {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Green -NoNewline; Write-Host "] " -NoNewline
        Write-Host "BepInEx Console Window  : " -NoNewline; Write-Host "Enabled & Clean (Shows startup loading without in-game lag)" -ForegroundColor Green
    } elseif ($conEnabled -eq "true" -and $conLevels -eq "All") {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Yellow -NoNewline; Write-Host "] " -NoNewline
        Write-Host "BepInEx Console Window  : " -NoNewline; Write-Host "Enabled & Verbose (Dumps all raw debug messages)" -ForegroundColor Yellow
    } else {
        Write-Host "   [" -NoNewline; Write-Host "X" -ForegroundColor DarkGray -NoNewline; Write-Host "] " -NoNewline
        Write-Host "BepInEx Console Window  : " -NoNewline; Write-Host "Disabled / Hidden (Silent background mode)" -ForegroundColor DarkGray
    }

    if ($diskUnity -eq "true") {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Yellow -NoNewline; Write-Host "] " -NoNewline
        Write-Host "Unity Engine Logging    : " -NoNewline; Write-Host "Enabled (Heavy I/O, writing all Unity engine logs)" -ForegroundColor Yellow
    } else {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Green -NoNewline; Write-Host "] " -NoNewline
        Write-Host "Unity Engine Logging    : " -NoNewline; Write-Host "Filtered / Suppressed (Fast zero-stutter I/O)" -ForegroundColor Green
    }

    if ($diskLevels -eq "All") {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Yellow -NoNewline; Write-Host "] " -NoNewline
        Write-Host "Disk Log Verbosity      : " -NoNewline; Write-Host "ALL (Verbose info, messages, warnings, errors)" -ForegroundColor Yellow
    } else {
        Write-Host "   [" -NoNewline; Write-Host ([char]0x221A) -ForegroundColor Green -NoNewline; Write-Host "] " -NoNewline
        Write-Host "Disk Log Verbosity      : " -NoNewline; Write-Host "Optimized (Errors & Warnings only)" -ForegroundColor Green
    }

    Write-Host "   [i] " -ForegroundColor Cyan -NoNewline
    Write-Host "Current Log File Size   : " -NoNewline; Write-Host "$logSizeStr" -ForegroundColor White
}
elseif ($Mode -eq "LogClear") {
    $logFile = Join-Path $GameDir "BepInEx\LogOutput.log"
    if (Test-Path $logFile) {
        Remove-Item -Force $logFile -ErrorAction SilentlyContinue
        Write-Host "  [SUCCESS] LogOutput.log has been cleared (0 KB)." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] No LogOutput.log found to clear." -ForegroundColor Gray
    }
}
