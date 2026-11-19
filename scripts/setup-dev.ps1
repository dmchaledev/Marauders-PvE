# One-time setup of a dev checkout: docs/DEVELOPING.md's "Setting it up on your PC" step 3 in one go.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-dev.ps1 [-Research]
# - Python packages from requirements.txt (with -Research also requirements-research.txt, for tools\).
# - config\game_path.txt: kept if it points at the game, else found in your Steam libraries, else asked for.
# - UE4SS v3.0.1 into tools\ue4ss, downloaded from its GitHub release and checked against a known SHA-256.
# Nothing in the game folder changes: that only happens on PLAY (scripts\mode.ps1 offline).
param([switch]$Research)
$ErrorActionPreference = 'Stop'
$Project = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'find-game.ps1')  # Find-Game, $ExeRel

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

# 1. Python packages. "py -3" first: a bare "python" can be the Microsoft Store stub.
$py = if (Get-Command py -ErrorAction SilentlyContinue) { @('py', '-3') } else { @('python') }
$pyExe, $pyPre = $py[0], @($py | Select-Object -Skip 1)
& $pyExe @pyPre -c "import sys; assert sys.version_info >= (3, 9)" 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Python 3.9 or newer is needed: install it from python.org (tick "Add Python to PATH").' }
$reqs = @('requirements.txt') + $(if ($Research) { @('requirements-research.txt') } else { @() })
foreach ($r in $reqs) {
    & $pyExe @pyPre -m pip install --user --disable-pip-version-check --quiet -r (Join-Path $Project $r)
    if ($LASTEXITCODE -ne 0) { throw "pip couldn't install $r" }
}
Say "Python:  $($reqs -join ', ') installed"

# 2. Where the game is.
$GamePath = Join-Path $Project 'config\game_path.txt'
$Game = $null
if (Test-Path $GamePath) {
    $Game = (Get-Content $GamePath -TotalCount 1).Trim()
    if (-not (Test-Path (Join-Path $Game $ExeRel))) { $Game = $null }
}
if (-not $Game) { $Game = Find-Game }
while (-not $Game) {
    $pick = (Read-Host "Couldn't find Marauders in your Steam libraries. Paste the game's folder (the one holding RaidGame)").Trim('" ')
    if ($pick -and (Test-Path (Join-Path $pick $ExeRel))) { $Game = $pick } else { Say "No $ExeRel there." Yellow }
}
[IO.File]::WriteAllText($GamePath, "$Game`n")
Say "Game:    $Game"

# 3. UE4SS v3.0.1 (the version the mods and config\UE4SS-settings.ini are written for).
$Ue4ss = Join-Path $Project 'tools\ue4ss'
$Url = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v3.0.1/UE4SS_v3.0.1.zip'
$Sha256 = '4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC'
if ((Test-Path (Join-Path $Ue4ss 'UE4SS.dll')) -and (Test-Path (Join-Path $Ue4ss 'dwmapi.dll')) -and (Test-Path (Join-Path $Ue4ss 'Mods'))) {
    Say "UE4SS:   already in tools\ue4ss"
} else {
    $zip = Join-Path ([IO.Path]::GetTempPath()) 'UE4SS_v3.0.1.zip'
    Say "Downloading UE4SS v3.0.1..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'  # Windows PowerShell's progress bar makes the download crawl
    Invoke-WebRequest $Url -OutFile $zip -UseBasicParsing
    $got = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($got -ne $Sha256) {
        Remove-Item $zip -Force
        throw "UE4SS download doesn't match the expected SHA-256 (got $got). Not installed."
    }
    New-Item -ItemType Directory -Force $Ue4ss | Out-Null
    Expand-Archive $zip $Ue4ss -Force
    Remove-Item $zip -Force
    Say "UE4SS:   v3.0.1 in tools\ue4ss (SHA-256 checked)"
}

Say "`nDone. Play with:  python launcher\launcher.pyw" Green
Say "If anything goes wrong:  powershell -NoProfile -File scripts\mode.ps1 online  (puts the game back to stock)" Gray
