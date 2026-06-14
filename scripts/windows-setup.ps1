# =============================================================================
# windows-setup.ps1 — One-shot environment bootstrap for this workflow on
# Windows, using winget. The Windows counterpart of scripts/mac-setup.sh.
#
# RUN IN A NORMAL PowerShell window (winget elevates per-package as needed):
#
#     powershell -ExecutionPolicy Bypass -File scripts\windows-setup.ps1
#
# Idempotent: re-running skips anything winget already reports installed.
# Stata is NOT installable here — it is licensed; install it from your
# institution's media, then Claude wires up stata-mcp separately.
# =============================================================================

$ErrorActionPreference = 'Stop'

function Say  ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Skip ($m) { Write-Host "  [skip] $m (already installed)" -ForegroundColor Yellow }

# winget must exist (ships with App Installer on Win10 1809+/Win11).
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    exit 1
}

function Install-IfMissing {
    param([string]$Id, [string]$Name)
    # `winget list --id` exits 0 and prints the row if installed.
    $installed = winget list --id $Id --exact 2>$null | Select-String $Id
    if ($installed) { Skip $Name; return }
    Say "Installing $Name ($Id) ..."
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    Ok $Name
}

# --- CLI tools ---
Install-IfMissing -Id 'Git.Git'        -Name 'Git'
Install-IfMissing -Id 'astral-sh.uv'   -Name 'uv (Python manager)'
Install-IfMissing -Id 'GitHub.cli'     -Name 'GitHub CLI'

# --- apps ---
Install-IfMissing -Id 'Posit.Quarto'   -Name 'Quarto'
Install-IfMissing -Id 'MiKTeX.MiKTeX'  -Name 'MiKTeX (XeLaTeX; auto-installs packages on first use)'
Install-IfMissing -Id 'RProject.R'     -Name 'R'

# --- Claude Code CLI (official installer; no winget package) ---
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Say "Installing the Claude Code CLI ..."
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
} else {
    Skip 'claude CLI'
}

Write-Host ""
Say "Done. Open a NEW PowerShell window so PATH updates take effect."
Write-Host "    TeX Live is an alternative to MiKTeX if you prefer (winget id: TeXLive.TeXLive)."
Write-Host "    Stata: install from your licensed media; then return to Claude to wire up stata-mcp."
Write-Host "    Then return to Claude and say 'done' — it will set up the Python env, R/Stata"
Write-Host "    packages, stata-mcp, and re-validate."
