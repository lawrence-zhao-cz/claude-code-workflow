#!/usr/bin/env bash
# =============================================================================
# mac-setup.sh — One-shot environment bootstrap for this workflow on macOS
#
# Installs the tools validate-setup.sh checks for, using Homebrew.
# RUN THIS IN A REAL TERMINAL (Terminal.app / iTerm) — Homebrew and the
# .pkg-based casks (MacTeX, R, Quarto) prompt for your sudo password, which
# only works in an interactive shell.
#
#   bash scripts/mac-setup.sh
#
# Idempotent: re-running skips anything already installed.
# Stata is assumed already installed (it is, with a license). stata-mcp is
# wired up separately by Claude after this script finishes.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
say()  { echo -e "${BOLD}==>${RESET} $*"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
skip() { echo -e "  ${YELLOW}•${RESET} $* (already present, skipping)"; }

# ---------------------------------------------------------------------------
# 1. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    say "Installing Homebrew (will prompt for your password)…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    skip "Homebrew"
fi

# Make brew available in THIS shell (Apple Silicon path) and persist for future
# shells. Harmless if the line is already in ~/.zprofile.
if [ -x /opt/homebrew/bin/brew ]; then
    if ! grep -q 'brew shellenv' "${HOME}/.zprofile" 2>/dev/null; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

command -v brew >/dev/null 2>&1 || { echo "Homebrew install failed — stopping."; exit 1; }
ok "brew: $(brew --version | head -n1)"

# ---------------------------------------------------------------------------
# 2. CLI formulae (no sudo)
# ---------------------------------------------------------------------------
say "Installing CLI tools via brew: uv, gh…"
for f in uv gh; do
    if brew list --formula "$f" >/dev/null 2>&1; then skip "$f"; else brew install "$f"; fi
done

# ---------------------------------------------------------------------------
# 3. Casks (these prompt for your password)
# ---------------------------------------------------------------------------
say "Installing apps via brew --cask: quarto, mactex (~5GB), r…"
for c in quarto mactex r; do
    if brew list --cask "$c" >/dev/null 2>&1; then skip "$c"; else brew install --cask "$c"; fi
done

# ---------------------------------------------------------------------------
# 4. Claude Code CLI (no sudo; installs to ~/.local/bin)
# ---------------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1 && [ ! -x "${HOME}/.local/bin/claude" ]; then
    say "Installing the Claude Code CLI…"
    curl -fsSL https://claude.ai/install.sh | bash
else
    skip "claude CLI"
fi

echo ""
say "Done. Open a NEW terminal (or run: source ~/.zprofile) so PATH updates take effect."
echo "    MacTeX adds itself under /Library/TeX; you may need a new shell for xelatex to appear."
echo "    Then return to Claude and say 'done' — it will configure stata-mcp and re-validate."
