---
name: setup-machine
description: Bootstrap a fresh Mac or Windows PC into a working workflow environment from scratch — first takes a READ-ONLY status pass across all five layers (system apps, the standalone Python env, R packages, Stata + stata-mcp, GitHub auth) so it installs only what is missing, then detects the OS and installs the system toolchain (XeLaTeX, Quarto, R, uv, git, gh, the Claude CLI) via Homebrew or winget, builds the STANDALONE uv-managed Python environment every analysis runs inside, installs the canonical R and Stata packages, wires up stata-mcp, enforces the LF line-ending guardrail that cross-platform Dropbox-synced repos need, and verifies the result with the same status pass. Use when user says "set up a new machine", "install the environment", "I'm on a new laptop", "bootstrap this repo", "get my Mac/PC ready", "install all the apps and packages", "check my environment", "what's installed", "verify my setup", or after cloning/forking the template onto fresh hardware. NOT for pinning exact versions for a replication package — that is /capture-environment.
argument-hint: "[--check] [--apps-only] [--packages-only] [--no-stata]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
disable-model-invocation: true
effort: medium
---

# `/setup-machine` — bootstrap the workflow toolchain on a new Mac or Windows PC

You sit down at a fresh laptop, clone (or Dropbox-sync) this repo, and nothing runs: no XeLaTeX, no Quarto, no uv, no R packages, the hooks fail because there is no Python on the path the harness expects. This skill takes that machine from bare to working — the same end state on macOS and Windows — and verifies it. It is the install-time counterpart to [`/capture-environment`](../capture-environment/SKILL.md): that skill *snapshots and pins* an environment for replication; this one *constructs* one on new hardware.

**Core principle:** the system installer (Homebrew / winget) handles *apps*; **uv** owns a **standalone Python** that every analysis runs inside (`uv run`), never the OS Python; package manifests in the repo are the single source of truth so the list can change without editing this skill. Stata is licensed and cannot be auto-installed — it must already be present.

## When to use

- **New machine / new laptop** — you switched hardware (Mac ↔ PC) and need the full toolchain back.
- **Just forked or cloned the template** — turn the scaffold into something that compiles, renders, and estimates.
- **A teammate / RA is onboarding** — give them one command per phase instead of a wiki of install steps.
- **After a partial install** — re-run any phase; every step is idempotent and skips what is already present.
- **`--check` / status only** — see exactly what is present vs missing across apps, the standalone Python env, R, and Stata without installing anything (`scripts/check-environment.sh`). Also the right answer to "what's installed?" / "is my environment OK?"

## Inputs (flags)

- `--check` — run only the deep status pass (all five layers) and report present/missing; install nothing.
- `--apps-only` — install the system toolchain (Phase 1) but skip the language packages (Phases 2–4).
- `--packages-only` — assume the apps are present; do only the Python / R / Stata package phases.
- `--no-stata` — skip the Stata ado install and stata-mcp wiring (for a machine without a Stata license).

## Workflow

### Phase 0: Status pass — what is already installed (always runs first)

Before touching anything, take a READ-ONLY inventory of the *whole* provisioned state — not just whether the apps exist, but whether the standalone Python env imports, the R packages load, and stata-mcp can drive Stata — so the install phases only fill genuine gaps. This is the same check Phase 6 re-runs to verify, so "did it work?" and "what's missing?" share one source of truth.

- **macOS / Linux:** `bash scripts/check-environment.sh` — reports all five layers: (1) the system toolchain (it wraps `validate-setup.sh` for apps + git + hooks + pre-commit gate + palette), (2) the standalone uv Python env + analysis-package imports, (3) the canonical R packages, (4) Stata + `uvx stata-mcp doctor`, (5) GitHub auth (`gh auth status`, so push/PR/merge work). Exit 0 means the required layers (apps + Python) are healthy; R/Stata/GitHub-auth gaps surface as warnings.
- **Windows:** run the same script in Git Bash (`bash scripts/check-environment.sh` — Git for Windows ships bash), or fall back to per-layer probes: `winget list` / `Get-Command` for apps, `uv run python -c "import pandas, pyfixest"`, `Rscript -e 'requireNamespace("fixest")'`, `uvx stata-mcp doctor`.

Determine the platform with `uname -s` (`Darwin` → macOS, `Linux` → Linux; on Windows you are in PowerShell/Git Bash). Read the report and install only what it marks ✗/missing. If `--check` is set, **stop here** — print the status and exit, changing nothing.

### Phase 1: System apps (skip if `--packages-only`)

These need an interactive sudo/UAC prompt the harness cannot answer, so they run in the **user's own terminal**. Hand off the one command and wait for the user to confirm completion:

- **macOS:** `bash scripts/mac-setup.sh` — installs [Homebrew](https://brew.sh), then `uv gh` (formulae) and `quarto mactex r` (casks), then the Claude CLI. See [`scripts/mac-setup.sh`](../../../scripts/mac-setup.sh).
- **Windows:** `powershell -ExecutionPolicy Bypass -File scripts\windows-setup.ps1` — installs Git, uv, GitHub CLI, Quarto, MiKTeX (XeLaTeX), R, and the Claude CLI via winget. See [`scripts/windows-setup.ps1`](../../../scripts/windows-setup.ps1).

Tell the user to open a **new** terminal afterward so PATH updates land, then continue.

### Phase 2: Standalone Python (skip if `--apps-only`)

Everything Python in this repo runs on a uv-managed standalone interpreter, not the system one. Build it from the repo manifests ([`pyproject.toml`](../../../pyproject.toml) + [`.python-version`](../../../.python-version)):

```bash
uv python install 3.13          # fetch the standalone CPython (isolated from system Python)
uv sync                         # create .venv + uv.lock from pyproject.toml
uv run python --version         # must report 3.13.x from the uv path, not /usr/bin/python3
```

From here, **every** analysis invocation is `uv run python scripts/python/…` (the [verification-protocol](../../rules/verification-protocol.md) and [python-code-conventions](../../rules/python-code-conventions.md) already assume this). Add `--extra causal-ml` to `uv sync` if `econml`/`doubleml` are needed.

### Phase 3: R packages (skip if `--apps-only`)

```bash
Rscript scripts/R/install-packages.R
```

Installs the canonical CRAN set (`tidyverse`, `fixest`, `did`, `DRDID`, `HonestDiD`, `modelsummary`, `haven`, `arrow`, …) plus best-effort GitHub-only packages; idempotent. See [`scripts/R/install-packages.R`](../../../scripts/R/install-packages.R).

### Phase 4: Stata ado + stata-mcp (skip if `--apps-only` or `--no-stata`)

Stata itself must already be installed and licensed (it cannot be automated). Wire up the MCP server and the ado packages:

1. Confirm [`.mcp.json`](../../../.mcp.json) declares the `stata-mcp` server (command `uvx`, args `["stata-mcp"]`); write it with the Write tool if missing.
2. Diagnose discovery: `uvx stata-mcp doctor` — it should find the Stata binary (here: `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp`).
3. Install the user-written commands by dispatching [`scripts/stata/00_install_ado.do`](../../../scripts/stata/00_install_ado.do) through the stata-mcp server (`reghdfe`, `ivreghdfe`, `csdid`, `drdid`, `estout`, `boottest`, …); idempotent.

### Phase 5: Cross-platform guardrails

These are what keep a Dropbox-synced Mac+PC repo from corrupting itself:

- **Line endings:** ensure [`.gitattributes`](../../../.gitattributes) exists with `* text=auto eol=lf` (forces LF in the working tree on every OS, overriding Windows' `core.autocrlf`). On Windows also set `git config --global core.autocrlf false` with the Bash tool, then `git add --renormalize .` once.
- **Hook interpreter:** the harness invokes the `.claude/hooks/*.py` hooks via bare `python` (see `.claude/settings.json`). On a stock Mac only `python3` exists, so the hooks silently fail. Make a `python` resolve to the standalone interpreter (`uv python install --default 3.13` installs `python`/`python3` shims on PATH), or change the hook commands to `uv run --project "$CLAUDE_PROJECT_DIR" python …` with the Edit tool. Confirm with `python --version` before relying on the hooks.

### Phase 6: Verify and report

Re-run the **same** read-only status pass from Phase 0 and confirm every layer is now green:

```bash
bash scripts/check-environment.sh
```

It smoke-tests each stack (apps answer `--version`, the standalone Python imports the analysis packages, R loads its packages, stata-mcp detects and executes Stata). Report the per-layer PASS/FAIL table and call out anything still missing (e.g. Stata not licensed on this box — expected under `--no-stata`). Per the [verification-protocol](../../rules/verification-protocol.md), end the run only when this check exits clean (or only the by-design R/Stata warnings remain).

## Output / what it changes

| Area | Effect |
|---|---|
| System apps | Homebrew/winget-installed XeLaTeX, Quarto, R, uv, git, gh, Claude CLI |
| Python | `.venv` + `uv.lock` built on standalone 3.13 from `pyproject.toml`; all analysis runs via `uv run` |
| R | canonical CRAN/GitHub packages installed into the user library |
| Stata | ado packages installed; `.mcp.json` stata-mcp server confirmed |
| Repo hygiene | `.gitattributes` (LF) present; `python` interpreter resolves for hooks |
| Always | a printed validation table; nothing committed (commit is a separate `/commit`) |

## Exit behavior

- **All phases succeed, validation clean:** exit 0 with the PASS table.
- **`--check`:** exit 0 (report-only) regardless of gaps; never installs.
- **A system installer needs the user's password:** pause, hand off the terminal command, resume when the user confirms — do not mark the phase done until `--version` answers.
- **Stata absent on a non-`--no-stata` run:** finish the other phases, exit 0, and flag Stata as a manual licensed install.
- **A package phase fails to resolve (yanked release, offline):** report the failing package and exit 1; do not silently continue as if the toolchain were complete.

## Cross-references

- [`scripts/check-environment.sh`](../../../scripts/check-environment.sh) — the read-only four-layer deep status the skill runs in Phase 0 (inventory) and Phase 6 (verify); the backbone of `--check`.
- [`scripts/validate-setup.sh`](../../../scripts/validate-setup.sh) — the app-layer ✓/✗ check (git, TeX, Quarto, Python, R, uv, gh, hooks, gate), wrapped by `check-environment.sh`.
- [`scripts/mac-setup.sh`](../../../scripts/mac-setup.sh) · [`scripts/windows-setup.ps1`](../../../scripts/windows-setup.ps1) — the per-OS system-app installers.
- [`pyproject.toml`](../../../pyproject.toml) · [`.python-version`](../../../.python-version) — the standalone Python manifest `uv sync` reads.
- [`scripts/R/install-packages.R`](../../../scripts/R/install-packages.R) · [`scripts/stata/00_install_ado.do`](../../../scripts/stata/00_install_ado.do) — the R and Stata package manifests.
- [`/capture-environment`](../capture-environment/SKILL.md) — the inverse skill: pins the exact versions of what this installed for a replication package.
- [`.claude/rules/python-code-conventions.md`](../../rules/python-code-conventions.md) — the uv / `uv run` discipline this skill provisions.
- [`CLAUDE.md`](../../../CLAUDE.md) — the Commands section whose tools this skill installs.

## What this skill does NOT do

- **Install or license Stata.** Stata is proprietary and not redistributable; the skill assumes it is present and only wires up stata-mcp + ado packages. On a machine without it, use `--no-stata`.
- **Pin exact versions for reproducibility.** It installs a working baseline; `/capture-environment` produces the `uv.lock` / `renv.lock` / Stata version record a replication package needs.
- **Manage per-paper dependencies.** A specific project that needs an unusual package adds it to `pyproject.toml` / the R or Stata manifest — this skill installs whatever those manifests currently list.
- **Commit anything.** It changes the working tree (`.venv`, lockfiles, configs); committing is a deliberate, separate `/commit`.

## Flags

- `--check` — inventory + validate only (Phase 0), install nothing; useful to see the gap list on a new box.
- `--apps-only` — Phase 1 only (system toolchain); skip the language-package phases.
- `--packages-only` — skip Phase 1; do the Python / R / Stata package phases against already-installed apps.
- `--no-stata` — skip Phase 4 entirely for a machine with no Stata license.
