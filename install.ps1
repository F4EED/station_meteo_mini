#Requires -Version 5.1
# Mini station météo — installation du client / configurateur web (Windows 10/11)
#   irm https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.ps1 | iex
#   ou double-clic install.bat
#   Raccourci seul :  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Icone
$ErrorActionPreference = "Stop"

$MiniRepo = "https://github.com/F4EED/station_meteo_mini.git"
$WebRepo = "https://github.com/F4EED/station_meteo_client_web.git"
$PnpmVersion = "11.9.0"
$Port = "5173"
$InstallDir = Join-Path $env:USERPROFILE "Station-meteo"

$IconeOnly = $false
foreach ($a in @($args)) {
    if ("$a" -match '^(?i)-?Icone$' -or "$a" -match '^(?i)-?Shortcut$') {
        $IconeOnly = $true
    }
}

function Say {
    param([string]$Message)
    Write-Host ""
    Write-Host (">> {0}" -f $Message) -ForegroundColor Cyan
}

function Have {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($machine -and $user) { $env:Path = "$machine;$user" }
    elseif ($machine) { $env:Path = $machine }
    elseif ($user) { $env:Path = $user }

    $extras = @(
        (Join-Path $env:APPDATA "npm"),
        (Join-Path $env:LOCALAPPDATA "pnpm"),
        "C:\Program Files\nodejs",
        "C:\Program Files\Git\cmd"
    )
    if (Have "node") {
        try { $extras += (Split-Path (Get-Command node -ErrorAction Stop).Source -Parent) } catch {}
    }
    foreach ($p in $extras) {
        if ($p -and (Test-Path $p) -and ($env:Path -notlike "*$p*")) {
            $env:Path = "$p;$env:Path"
        }
    }

    $parts = $env:Path -split ";" | Where-Object {
        $_ -and ($_ -notmatch '(?i)[\\/]Python[\\/].*[\\/]Scripts') -and ($_ -notmatch '(?i)meshtastic')
    }
    $env:Path = ($parts -join ";")
}

function Get-NpmCmd {
    Refresh-Path
    $c = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c = Get-Command npm -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $guess = "C:\Program Files\nodejs\npm.cmd"
    if (Test-Path $guess) { return $guess }
    return $null
}

function Get-PnpmLauncher {
    Refresh-Path
    foreach ($name in @("pnpm.cmd", "pnpm")) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $c) { continue }
        if ($c.Source -match "(?i)Python|meshtastic") { continue }
        return $c.Source
    }
    $candidates = @(
        (Join-Path $env:APPDATA "npm\pnpm.cmd"),
        (Join-Path $env:APPDATA "npm\pnpm"),
        (Join-Path $env:LOCALAPPDATA "pnpm\pnpm.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $npmCmd = Get-NpmCmd
    if ($npmCmd) {
        try {
            $prev = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $root = & $npmCmd root -g 2>$null
            $ErrorActionPreference = $prev
            if ($root) {
                $cjs = Join-Path $root.Trim() "pnpm\bin\pnpm.cjs"
                if (Test-Path $cjs) { return "node|$cjs" }
            }
        } catch {}
    }
    return $null
}

function Invoke-StMetPnpm {
    param([Parameter(Mandatory = $true)][string[]]$PnpmArgs)
    $env:HUSKY = "0"
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Refresh-Path
        $launcher = Get-PnpmLauncher
        if ($launcher -and $launcher.StartsWith("node|")) {
            $cjs = $launcher.Substring(5)
            & node $cjs @PnpmArgs
        } elseif ($launcher) {
            & $launcher @PnpmArgs
        } else {
            $npmCmd = Get-NpmCmd
            if (-not $npmCmd) {
                Write-Host "npm introuvable."
                return 1
            }
            & $npmCmd exec --yes -- ("pnpm@{0}" -f $PnpmVersion) @PnpmArgs
        }
        if ($null -eq $LASTEXITCODE) { return 0 }
        return [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEa
    }
}

function Install-StMetPnpm {
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Refresh-Path
        $npmCmd = Get-NpmCmd
        if (-not $npmCmd) {
            Write-Host "npm introuvable apres Node. Rouvrez Terminal et relancez."
            return $false
        }
        Write-Host ("npm : {0}" -f $npmCmd)
        Write-Host ("Installation pnpm@{0} (npm -g)..." -f $PnpmVersion)
        & $npmCmd install -g ("pnpm@{0}" -f $PnpmVersion) 2>&1 | Out-Host
        Refresh-Path
        if (Get-PnpmLauncher) { return $true }

        Write-Host "Repli : installateur officiel pnpm..."
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "https://get.pnpm.io/install.ps1" -OutFile (Join-Path $env:TEMP "pnpm-get.ps1")
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $env:TEMP "pnpm-get.ps1") 2>&1 | Out-Host
            Refresh-Path
        } catch {
            Write-Host ("Installateur pnpm : {0}" -f $_.Exception.Message)
        }
        if (Get-PnpmLauncher) { return $true }

        Write-Host "Repli : npm exec pnpm (sans install globale)..."
        $out = & $npmCmd exec --yes -- ("pnpm@{0}" -f $PnpmVersion) --version 2>&1
        $out | Out-Host
        return ($LASTEXITCODE -eq 0 -or ("$out" -match '\d+\.\d+\.\d+'))
    } finally {
        $ErrorActionPreference = $prevEa
    }
}

function Get-DesktopDir {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ($desktop -and (Test-Path $desktop)) { return $desktop }
    foreach ($name in @("Bureau", "Desktop")) {
        $p = Join-Path $env:USERPROFILE $name
        if (Test-Path $p) { return $p }
    }
    $p = Join-Path $env:USERPROFILE "Desktop"
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-ChromeOrEdge {
    $candidates = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LocalAppData}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    foreach ($name in @("chrome", "msedge")) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if ($c) { return $c.Source }
    }
    return $null
}

function Ensure-Chrome {
    if (Get-ChromeOrEdge) {
        Write-Host ("Navigateur OK : {0}" -f (Get-ChromeOrEdge))
        return
    }
    if (-not (Have "winget")) {
        Write-Host "Installez Google Chrome : https://www.google.com/chrome/"
        Write-Host "Firefox n'a pas Web Bluetooth."
        return
    }
    Write-Host "Installation de Google Chrome (Web Bluetooth / Web Serial)..."
    winget install --id Google.Chrome -e --source winget --accept-package-agreements --accept-source-agreements
    Refresh-Path
    if (Get-ChromeOrEdge) {
        Write-Host ("Navigateur installe : {0}" -f (Get-ChromeOrEdge))
    } else {
        Write-Host "Chrome non detecte. Installez-le depuis https://www.google.com/chrome/"
        Write-Host "Edge convient aussi. Firefox : USB seulement, pas de BLE."
    }
}

function New-StMetShortcut {
    param([Parameter(Mandatory = $true)][string]$Dir)

    $web = Join-Path $Dir "station_meteo_client_web"
    if (-not (Test-Path (Join-Path $web "package.json"))) {
        Write-Host "Client web introuvable. Lancez d'abord l'installation :"
        Write-Host "  irm https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.ps1 | iex"
        exit 1
    }

    $nodeDir = "C:\Program Files\nodejs"
    $nodeExe = Join-Path $nodeDir "node.exe"
    $npmCmd = Join-Path $nodeDir "npm.cmd"
    if (-not (Test-Path $nodeExe)) {
        $n = Get-Command node -ErrorAction SilentlyContinue
        if ($n) {
            $nodeExe = $n.Source
            $nodeDir = Split-Path $nodeExe -Parent
            $npmCmd = Join-Path $nodeDir "npm.cmd"
        }
    }
    $npmGlobal = Join-Path $env:APPDATA "npm"
    $pnpmCmd = Join-Path $npmGlobal "pnpm.cmd"
    $pnpmMjsApp = Join-Path $npmGlobal "node_modules\pnpm\bin\pnpm.mjs"
    $pnpmMjsLocal = Join-Path $web "node_modules\pnpm\bin\pnpm.mjs"
    $browser = Get-ChromeOrEdge
    if (-not $browser) { $browser = "" }

    $demarrerBat = Join-Path $Dir "demarrer.bat"
    $demarrerContent = @"
@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "$web"
set HUSKY=0
set "STMET_NODE=$nodeExe"
set "STMET_NPM=$npmCmd"
set "STMET_PNPM_CMD=$pnpmCmd"
set "STMET_PNPM_MJS=$pnpmMjsApp"
if exist "$pnpmMjsLocal" set "STMET_PNPM_MJS=$pnpmMjsLocal"
set "STMET_BROWSER=$browser"
set "PATH=$nodeDir;$npmGlobal;%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem"

echo.
echo ========================================
echo   Station meteo - client web
echo ========================================
echo   Chrome / Edge (Bluetooth + USB) :
echo     http://127.0.0.1:$Port/
echo   Firefox : USB seulement, pas de BLE.
echo   Laissez cette fenetre ouverte.
echo   Ctrl+C pour arreter.
echo ========================================
echo.

if not exist "%STMET_NODE%" (
  echo Node.js introuvable. Reinstallez Node LTS depuis https://nodejs.org/
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo Premiere fois : pnpm install...
  if exist "%STMET_PNPM_MJS%" (
    "%STMET_NODE%" "%STMET_PNPM_MJS%" install
  ) else if exist "%STMET_PNPM_CMD%" (
    call "%STMET_PNPM_CMD%" install
  ) else if exist "%STMET_NPM%" (
    call "%STMET_NPM%" exec --yes -- pnpm@$PnpmVersion install
  )
)

if exist "%STMET_BROWSER%" (
  start "" "%STMET_BROWSER%" --user-data-dir="%LOCALAPPDATA%\station-meteo-chromium" --new-window --enable-features=WebBluetooth,WebBluetoothNewPermissionsBackend,WebSerial "http://127.0.0.1:$Port/"
) else (
  start "" "http://127.0.0.1:$Port/"
)

if exist "%STMET_PNPM_MJS%" (
  "%STMET_NODE%" "%STMET_PNPM_MJS%" --filter meshtastic-web dev --host 127.0.0.1 --port $Port
  goto :fin
)
if exist "%STMET_PNPM_CMD%" (
  call "%STMET_PNPM_CMD%" --filter meshtastic-web dev --host 127.0.0.1 --port $Port
  goto :fin
)
if exist "%STMET_NPM%" (
  call "%STMET_NPM%" exec --yes -- pnpm@$PnpmVersion --filter meshtastic-web dev --host 127.0.0.1 --port $Port
  goto :fin
)

echo Impossible de lancer pnpm/vite. Relancez l'install :
echo   irm https://raw.githubusercontent.com/F4EED/station_meteo_mini/main/install.ps1 ^| iex
pause
exit /b 1

:fin
echo.
pause
endlocal
"@
    Write-Utf8NoBom -Path $demarrerBat -Content $demarrerContent

    $iconIco = Join-Path $Dir "assets\station-meteo.ico"
    $iconPng = Join-Path $Dir "assets\station-meteo.png"
    $faviconIco = Join-Path $web "apps\web\public\favicon.ico"
    $iconForLnk = $null
    if (Test-Path $iconIco) { $iconForLnk = $iconIco }
    elseif (Test-Path $faviconIco) { $iconForLnk = $faviconIco }
    elseif (Test-Path $iconPng) { $iconForLnk = $iconPng }

    $desktopDir = Get-DesktopDir
    $desktopLnk = Join-Path $desktopDir "Station meteo.lnk"
    $desktopBat = Join-Path $desktopDir "Station-meteo.bat"

    Copy-Item $demarrerBat (Join-Path $env:USERPROFILE "start_StMet.bat") -Force
    Copy-Item $demarrerBat $desktopBat -Force

    $lnkOk = $false
    try {
        $w = New-Object -ComObject WScript.Shell
        $s = $w.CreateShortcut($desktopLnk)
        $s.TargetPath = "$env:ComSpec"
        $s.Arguments = "/c `"$demarrerBat`""
        $s.WorkingDirectory = $Dir
        $s.WindowStyle = 1
        $s.Description = "Station meteo - client / configurateur web"
        if ($iconForLnk) { $s.IconLocation = "$iconForLnk,0" }
        $s.Save()
        $lnkOk = $true
    } catch {
        $lnkOk = $false
    }

    Write-Host ""
    Write-Host ("Bureau detecte : {0}" -f $desktopDir)
    if ($lnkOk) {
        Write-Host ("Raccourci : {0}" -f $desktopLnk)
    } else {
        Write-Host "Echec .lnk - utilisez Station-meteo.bat sur le Bureau."
    }
    Write-Host ("Bat       : {0}" -f $desktopBat)
    Write-Host ("Aussi     : {0}" -f (Join-Path $env:USERPROFILE "start_StMet.bat"))
    Write-Host ""
}

try {
    if ($PSScriptRoot) {
        $rootCandidate = $PSScriptRoot
        if ((Test-Path (Join-Path $rootCandidate "start_StMet.sh")) -or
            (Test-Path (Join-Path $rootCandidate "README.md"))) {
            if (Test-Path (Join-Path $rootCandidate "install.ps1")) {
                $InstallDir = $rootCandidate
            }
        }
    }
} catch {}

if ($IconeOnly) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Station meteo - raccourci Bureau"
    Write-Host "========================================"
    New-StMetShortcut -Dir $InstallDir
    exit 0
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Station meteo - installation Windows"
Write-Host "========================================"
Write-Host ("  Dossier : {0}" -f $InstallDir)
Write-Host "========================================"

Say "1/5 - Git, Node.js, Chrome"
Refresh-Path
if (-not (Have "git") -or -not (Have "node")) {
    if (-not (Have "winget")) {
        Write-Host "Installez Git + Node LTS puis relancez :"
        Write-Host "  https://git-scm.com/download/win"
        Write-Host "  https://nodejs.org/"
        Read-Host "Entree pour fermer"
        exit 1
    }
    if (-not (Have "git")) {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        Refresh-Path
    }
    if (-not (Have "node")) {
        winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-package-agreements --accept-source-agreements
        Refresh-Path
    }
}
if (-not (Have "git") -or -not (Have "node")) {
    Write-Host "Fermez cette fenetre, rouvrez Terminal, puis relancez."
    Read-Host "Entree pour fermer"
    exit 1
}
Write-Host ("OK - Node {0}" -f (node -v))
$npmCmd = Get-NpmCmd
if (-not $npmCmd) {
    Write-Host "Node est la mais npm manque. Reinstallez Node.js LTS depuis https://nodejs.org/"
    Read-Host "Entree pour fermer"
    exit 1
}
Write-Host ("OK - npm {0}" -f (& $npmCmd -v))
Ensure-Chrome

Say "2/5 - pnpm"
$env:HUSKY = "0"
if (-not (Install-StMetPnpm)) {
    Write-Host ""
    Write-Host "Impossible d'executer pnpm." -ForegroundColor Red
    Write-Host ("  npm install -g pnpm@{0}" -f $PnpmVersion)
    Read-Host "Entree pour fermer"
    exit 1
}
Write-Host "OK - pnpm"

Say "3/5 - Telechargement"
if ((Test-Path (Join-Path $InstallDir "start_StMet.sh")) -or
    (Test-Path (Join-Path $InstallDir "install.ps1"))) {
    if (Test-Path (Join-Path $InstallDir ".git")) {
        try { & git -C $InstallDir pull --ff-only 2>&1 | Out-Null } catch {}
    }
} else {
    if (Test-Path $InstallDir) {
        Write-Host ("Le dossier {0} existe deja et n'est pas la mini station." -f $InstallDir)
        Write-Host "Renommez-le ou supprimez-le, puis relancez."
        Read-Host "Entree pour fermer"
        exit 1
    }
    & git clone --depth 1 $MiniRepo $InstallDir
}

$webDir = Join-Path $InstallDir "station_meteo_client_web"
if (Test-Path (Join-Path $webDir "apps\web")) {
    if (Test-Path (Join-Path $webDir ".git")) {
        try { & git -C $webDir pull --ff-only 2>&1 | Out-Null } catch {}
    }
} else {
    & git clone --depth 1 $WebRepo $webDir
}

Say "4/5 - Installation des composants (2-5 min)..."
Set-Location $webDir
$logFile = Join-Path $env:TEMP "stmet-pnpm-install.log"
$env:HUSKY = "0"
$prevEa = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$installOutput = Invoke-StMetPnpm @("install", "--reporter=append-only") 2>&1
$installCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
$ErrorActionPreference = $prevEa
$installOutput | Tee-Object -FilePath $logFile | Out-Host
if ($installCode -ne 0) {
    Write-Host ""
    Write-Host ("ECHEC pnpm install (code {0})." -f $installCode) -ForegroundColor Red
    Write-Host ("Journal : {0}" -f $logFile)
    Read-Host "Entree pour fermer"
    exit 1
}

Say "5/5 - Raccourci Bureau"
New-StMetShortcut -Dir $InstallDir

Write-Host ""
Write-Host "========================================"
Write-Host "  C est pret."
Write-Host ""
Write-Host "  Double-cliquez « Station meteo » sur le Bureau."
Write-Host ("  URL : http://127.0.0.1:{0}/" -f $Port)
Write-Host ""
Write-Host "  Chrome / Edge : Web Bluetooth + Web Serial natifs."
Write-Host "  Firefox : pas de BLE (USB = onglet Serial, Firefox 151+)."
Write-Host "  PIN BLE usine : 123456"
Write-Host "  Ne pas appairer le noeud dans Parametres > Bluetooth avant le navigateur."
Write-Host ""
Write-Host "  Recreer le raccourci :"
Write-Host "    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Icone"
Write-Host "========================================"
Write-Host ""
Read-Host "Entree pour fermer"
