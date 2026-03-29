#Requires -Version 5.1
<#
.SYNOPSIS
    Developer install: editable install, fusion-cam --install (Fusion bridge add-in).
    Tries pip install --user -e . first; falls back to .venv if blocked (e.g. store Python).
    Set FUSION_CAM_INSTALL_USE_VENV=1 to always use .venv.
.EXAMPLE
    cd fusion-cam-cli; .\install.ps1
.EXAMPLE
    irm https://raw.githubusercontent.com/BJam/fusion-cam-cli/main/install.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoUrl = if ($env:FUSION_CAM_REPO_URL) { $env:FUSION_CAM_REPO_URL } else { "https://github.com/bjam/fusion-cam-cli.git" }
$CloneDir = $env:FUSION_CAM_CLONE_DIR
$UseVenv = $env:FUSION_CAM_INSTALL_USE_VENV

function Write-Info { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Err  { param([string]$Msg) Write-Host "  ✗ $Msg" -ForegroundColor Red }

function Get-UserScriptsDir {
    $base = (& python3 -c "import site; print(site.getuserbase())").Trim()
    return (Join-Path $base "Scripts")
}

function Test-RepoRoot {
    return (Test-Path -LiteralPath "pyproject.toml") -and (Select-String -Path "pyproject.toml" -Pattern 'name = "fusion-cam-cli"' -Quiet)
}

function Ensure-Repo {
    if (Test-RepoRoot) { return }
    if (-not $CloneDir) {
        Write-Err "Not in the fusion-cam-cli repo root. Clone first, or set FUSION_CAM_CLONE_DIR:"
        Write-Err "  git clone $RepoUrl; cd fusion-cam-cli; .\install.ps1"
        exit 1
    }
    if (-not (Test-Path -LiteralPath $CloneDir)) {
        Write-Info "Cloning into $CloneDir"
        git clone --depth 1 $RepoUrl $CloneDir
    }
    Set-Location $CloneDir
}

function Add-FusionCamShim {
    param([string]$TargetExe)
    $localBin = Join-Path $env:USERPROFILE ".local\bin"
    New-Item -ItemType Directory -Force -Path $localBin | Out-Null
    $target = (Resolve-Path -LiteralPath $TargetExe).Path
    $cmdPath = Join-Path $localBin "fusion-cam.cmd"
    # cmd wrapper: forward all args to the real console_script
    $content = "@echo off`r`n""$target"" %*"
    Set-Content -LiteralPath $cmdPath -Value $content -Encoding ascii
    Write-Info "fusion-cam → $cmdPath"
}

function Install-InVenv {
    if (-not (Test-Path -LiteralPath ".venv")) {
        Write-Info "Creating .venv"
        & python3 -m venv .venv
    }
    $venvPy = Join-Path (Get-Location) ".venv\Scripts\python.exe"
    & $venvPy -m pip install -q --upgrade pip
    Write-Host ""
    Write-Host "── pip install -e . (venv) ──"
    & $venvPy -m pip install -e .
}

function Main {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗"
    Write-Host "  ║  Fusion 360 CAM CLI — developer install      ║"
    Write-Host "  ╚══════════════════════════════════════════════╝"
    Write-Host ""

    Ensure-Repo

    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) {
        Write-Err "python3 not found. Install Python 3.10+ and retry."
        exit 1
    }

    $fusionCam = $null
    $installedMode = $null

    if ($UseVenv -and $UseVenv -ne "0") {
        Write-Info "Using virtual environment (FUSION_CAM_INSTALL_USE_VENV is set)"
        Install-InVenv
        $fusionCam = Join-Path (Get-Location) ".venv\Scripts\fusion-cam.exe"
        $installedMode = "venv"
    }
    else {
        Write-Info "Trying editable install for your user (no venv) …"
        Write-Host ""
        Write-Host "── pip install --user -e . ──"
        & python3 -m pip install -q --user -e . 2>$null
        if ($LASTEXITCODE -eq 0) {
            $scripts = Get-UserScriptsDir
            $candidate = Join-Path $scripts "fusion-cam.exe"
            if (Test-Path -LiteralPath $candidate) {
                $fusionCam = $candidate
                $installedMode = "user"
                Write-Info "User install OK"
            }
        }
        if (-not $installedMode) {
            Write-Host ""
            Write-Info "User install unavailable. Using .venv."
            Install-InVenv
            $fusionCam = Join-Path (Get-Location) ".venv\Scripts\fusion-cam.exe"
            $installedMode = "venv"
        }
    }

    Write-Host ""
    Write-Host "── Link fusion-cam into ~/.local/bin ──"
    Add-FusionCamShim -TargetExe $fusionCam

    Write-Host ""
    Write-Host "── fusion-cam --install (Fusion bridge add-in) ──"
    & $fusionCam --install

    Write-Host ""
    Write-Info "Done."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Open Fusion 360 → Scripts and Add-ins → run add-in: fusion-bridge"
    Write-Host "  2. Use the CLI:  fusion-cam ping"
    $localBin = Join-Path $env:USERPROFILE ".local\bin"
    if ($env:PATH -notlike "*$localBin*") {
        Write-Host "     If fusion-cam is not found, add this folder to your user PATH:"
        Write-Host "       $localBin"
    }
    Write-Host "  3. Cursor: keep .cursor/rules/fusion-cam-cli.mdc for agent guidance"
    Write-Host "  4. Force venv: `$env:FUSION_CAM_INSTALL_USE_VENV='1'; .\install.ps1"
    Write-Host ""
}

Main
