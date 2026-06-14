#!/usr/bin/env bash
# =============================================================================
# check-environment.sh — READ-ONLY deep status of the workflow environment.
#
# validate-setup.sh answers "are the APPS installed?". This goes a layer
# deeper and reports the whole provisioned state across all four stacks:
#
#   1. System toolchain   (delegates to validate-setup.sh)
#   2. Python             (standalone uv env exists + analysis packages import)
#   3. R                  (canonical analysis packages load)
#   4. Stata + stata-mcp  (uvx stata-mcp doctor: Stata detected + executes)
#
# Installs NOTHING. Used by /setup-machine for the Phase 0 inventory (decide
# what to install) and the Phase 6 verify (confirm what was installed), and
# runnable on its own:  bash scripts/check-environment.sh
#
# Cross-platform: runs on macOS/Linux and on Windows via Git Bash (ships with
# Git for Windows). Stata is auto-detected by stata-mcp, so no hardcoded path.
#
# Exit: 0 if the required layers (apps + Python env) are healthy; 1 otherwise.
# R and Stata gaps are reported as warnings (a machine may legitimately lack a
# Stata license — see /setup-machine --no-stata).
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
fail=0; warn=0

hdr() { echo ""; echo -e "${BOLD}── $* ──${RESET}"; }

# --- Layer 1: system toolchain (apps, git, hooks, gate, palette) -------------
hdr "1. System toolchain"
if bash "$DIR/validate-setup.sh"; then
    :   # validate-setup.sh prints its own ✓/✗ table + summary
else
    fail=1
fi

# --- Layer 2: standalone Python env + analysis packages ----------------------
hdr "2. Python (standalone uv environment)"
if ! command -v uv >/dev/null 2>&1; then
    echo -e "  ${RED}✗${RESET} uv not installed — run /setup-machine (Phase 1)"
    fail=1
elif [ ! -d "$ROOT/.venv" ]; then
    echo -e "  ${RED}✗${RESET} no .venv — run: uv sync"
    fail=1
else
    pyout="$(uv run --project "$ROOT" python - <<'PY' 2>/dev/null
import importlib.util, sys
mods = ["pandas","numpy","scipy","statsmodels","linearmodels",
        "pyfixest","matplotlib","pyreadstat","pyarrow"]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
print(sys.version.split()[0] + "|" + sys.executable + "|" + ",".join(missing))
PY
)"
    ver="${pyout%%|*}"; rest="${pyout#*|}"; exe="${rest%%|*}"; miss="${rest##*|}"
    if [ -z "$ver" ]; then
        echo -e "  ${RED}✗${RESET} uv env present but Python failed to run — try: uv sync"
        fail=1
    else
        case "$exe" in
            *"/.venv/"*) loc="standalone (.venv)";;
            *) loc="$exe";;
        esac
        echo -e "  ${GREEN}✓${RESET} Python $ver — $loc"
        if [ -n "$miss" ]; then
            echo -e "  ${RED}✗${RESET} missing packages: $miss — run: uv sync"
            fail=1
        else
            echo -e "  ${GREEN}✓${RESET} analysis packages import (pandas, pyfixest, linearmodels, …)"
        fi
    fi
fi

# --- Layer 3: R analysis packages --------------------------------------------
hdr "3. R analysis packages"
if ! command -v Rscript >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠${RESET} R not installed (optional) — /setup-machine installs it"
    warn=1
else
    rmiss="$(Rscript -e 'p<-c("tidyverse","fixest","did","DRDID","modelsummary","haven","arrow"); m<-p[!vapply(p,requireNamespace,logical(1),quietly=TRUE)]; cat(paste(m,collapse=","))' 2>/dev/null)"
    if [ -z "$rmiss" ]; then
        echo -e "  ${GREEN}✓${RESET} canonical R packages load (fixest, did, DRDID, modelsummary, haven, arrow)"
    else
        echo -e "  ${YELLOW}⚠${RESET} missing R packages: $rmiss — run: Rscript scripts/R/install-packages.R"
        warn=1
    fi
fi

# --- Layer 4: Stata + stata-mcp ----------------------------------------------
hdr "4. Stata + stata-mcp"
if ! command -v uvx >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠${RESET} uvx unavailable — cannot probe stata-mcp"
    warn=1
else
    doc="$(uvx stata-mcp doctor 2>&1)"
    if echo "$doc" | grep -q "stata_cli.*PASS\|\[PASS\] stata_cli"; then
        echo -e "  ${GREEN}✓${RESET} Stata detected and stata-mcp executes"
        echo "$doc" | grep -E "\[(PASS|FAIL|WARN)\] (stata_cli|stata_execution)" | sed 's/^/      /'
    elif echo "$doc" | grep -q "stata_cli"; then
        echo -e "  ${YELLOW}⚠${RESET} stata-mcp ran but Stata not detected (no license on this box?) — use --no-stata"
        echo "$doc" | grep -E "\[(PASS|FAIL|WARN)\] stata" | sed 's/^/      /'
        warn=1
    else
        echo -e "  ${YELLOW}⚠${RESET} stata-mcp doctor did not report a Stata status; first run may be fetching the package"
        warn=1
    fi
fi

# --- Summary -----------------------------------------------------------------
hdr "Summary"
if [ "$fail" -ne 0 ]; then
    echo -e "  ${RED}Required layers incomplete.${RESET} Run /setup-machine to fill the gaps above."
    exit 1
elif [ "$warn" -ne 0 ]; then
    echo -e "  ${GREEN}Required layers OK${RESET}, ${YELLOW}with warnings${RESET} (R and/or Stata) — see above."
    exit 0
else
    echo -e "  ${GREEN}All four layers healthy.${RESET} Environment is fully provisioned."
    exit 0
fi
