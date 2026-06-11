---
name: data-analysis-stata
description: End-to-end Stata data analysis pipeline — scaffolds numbered `.do` files in `scripts/stata/`, executes them via the `stata-mcp` MCP server, captures logs and outputs to `scripts/stata/_outputs/`, and produces publication-ready tables (esttab) and figures (graph export). The Stata member of the analysis triad (/data-analysis-r, /data-analysis-python); the default for estimation in this project's language roles. Use when user says "run this in Stata", "set up Stata pipeline", "scaffold the .do files", "run Stata analysis", "reghdfe/csdid/ivreghdfe regression", "AEA replication package in Stata", or when the project's estimation language is Stata.
argument-hint: "[paper-or-data-pointer] [--from-r] [--no-execute] [--no-crosscheck] [--prep-only]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "Monitor"]
---

# `/data-analysis-stata` — Stata pipeline scaffold + execution

Build a complete Stata analysis pipeline in `scripts/stata/`: numbered `.do` files following [`.claude/rules/stata-code-conventions.md`](../../rules/stata-code-conventions.md), executed via the [`stata-mcp`](https://github.com/SepineTam/stata-mcp) MCP server, with outputs landing in `scripts/stata/_outputs/`.

## When to use

- Your project's **estimation language is Stata** (the default in this project's language-roles table — CLAUDE.md "Project Language Roles"). Canonical applied-micro estimators (`reghdfe`, `csdid`, `ivreghdfe`) + referee/AEA norms.
- A mixed pipeline hands off to Stata: prep = Python produced a `.dta`, this skill estimates from it.
- You want a one-command reproduction: `do scripts/stata/99_run_all.do`.
- **Secondary (replication/porting) use:** you're porting an R-first project to Stata for an AEA submission (`--from-r`), or adding a Stata robustness check to an R-first paper. This was the skill's original purpose (v1.9.0, as `/stata-replication`); it remains fully supported.

## When NOT to use

- Your project is R-first. Use [`/data-analysis-r`](../data-analysis-r/SKILL.md).
- Your project is Python-first. Use [`/data-analysis-python`](../data-analysis-python/SKILL.md) — or, in a mixed pipeline (prep = Python, estimation = Stata per the CLAUDE.md language roles), let `/data-analysis-python` produce the `.dta` handoff and run this skill for the estimation phase.
- You're doing quick exploratory work. The numbered-pipeline scaffold is for replication packages, not scratch notebooks.

## Prerequisite: `stata-mcp` installed

This skill requires the `stata-mcp` MCP server. Install once per user:

```bash
claude mcp add stata-mcp --scope user -- uvx stata-mcp
```

The MCP server provides command-guarded Stata execution (refuses destructive operations like `!/shell/erase`), RAM monitoring, and Stata Language Server pairing. Maintained by SepineTam, 171 stars on GitHub as of 2026-05.

If `stata-mcp` is not installed, the skill halts at Phase 0 with installation instructions.

## Workflow

### Phase 0: Pre-flight

1. Verify `stata-mcp` is registered in the user's MCP configuration. If not → halt with install instructions.
2. Verify Stata is installed locally (the MCP server cannot run without it). Output stata version to confirm.
3. Confirm `scripts/stata/` directory exists or can be created.
4. Read [`.claude/rules/stata-code-conventions.md`](../../rules/stata-code-conventions.md) — every emitted `.do` file follows this convention.
5. If `--from-r` flag is set, locate the existing R pipeline at `scripts/R/` and use it as a translation source. Apply the Stata → R pitfalls table from `replication-protocol.md` in reverse.
6. **Produce a Pre-Flight Report** (same contract as the R and Python siblings) before writing any `.do` file:

```markdown
## Pre-Flight Report
**Dataset:** [path]
- Variables: [from `describe`]   Rows: [from `count`]
- Key types: [outcome=float, treat=byte, state=str/encoded]
- Missingness: [% missing per key var — remember `.` sorts as +∞ in filters]
**Language roles (from CLAUDE.md):** prep=[..] estimate=[..] cross-check=[..]
**Conventions read:** stata-code-conventions.md — [most relevant rule]
**Task interpretation:** [one sentence]
**Plan:** [3–5 bullet outline of the .do pipeline]
```

If an input can't be read, stop and ask before proceeding.

**Analysis plan integration:** if `scripts/analysis_plans/<slug>.md` exists for this project, load it — it is **authoritative** (`single-source-of-truth.md`). Execute specifications **by ID** (the Pre-Flight reports "executing R3–R7" instead of re-interpreting prose). A requested regression not in the plan → log it first via `/analysis-plan --log-adhoc` (never silently bypass). After runs, update the plan (spec Status → RUN; output paths into the registry). Mid-analysis spec changes go through `/analysis-plan --amend` — document first, code second.

### Phase 1: Scaffold the pipeline

Emit (or update) these files in `scripts/stata/`, each conforming to the header convention from `stata-code-conventions.md`:

```
scripts/stata/
├── 00_install.do        # ssc install, set globals, paths, sessionInfo capture
├── 01_clean.do          # raw → cleaned panel; ends with assert-based validation:
│                        #   merge ..., assert(3) · isid key check · assert _N == ...
│                        #   value-range asserts (assert inrange(share, 0, 1))
│                        #   misstable summarize snapshot (the Stata twin of the §7 battery)
├── 02_descriptive.do    # summary stats + distributions (summarize, detail / histogram),
│                        #   missingness, time patterns for panels; balance (iebaltab) +
│                        #   attrition as the RCT-specific extras
├── 03_analyze.do        # main specs (reghdfe / ivreg2): documented cluster level,
│                        #   progressive specifications across columns, standardized
│                        #   effects where meaningful; diagnostics before trusting a
│                        #   spec (estat vif, influential obs, perfect prediction/
│                        #   separation); ends with estimates save
│                        #   scripts/stata/_outputs/est_<spec>.ster per spec
├── 04_robustness.do     # alt specs, sensitivity
├── 05_tables_figures.do # estimates use + esttab .tex (never re-runs models);
│                        #   graph export PDF + PNG per stata-code-conventions.md §8
└── 99_run_all.do        # do "01_clean.do" / do "02_..." / ...
```

If the paper or data source suggests specific specs (e.g., DiD with `reghdfe`, IV with `ivreg2`, RD with `rdrobust`), tailor `03_analyze.do` accordingly.

If `--prep-only` was passed (or the language roles assign estimation elsewhere — rare for Stata, which is this project's default estimator), scaffold and run only `00_install.do` + `01_clean.do`: end the cleaning with `merge ..., assert()` discipline and explicit assertions, `save` the cleaned `.dta` handoff, and stop.

### Phase 2: Execute (unless `--no-execute`)

For each script in numbered order:

1. Dispatch to `stata-mcp` to execute the `.do` file.
2. Capture the log (Stata writes to `scripts/stata/_outputs/NN_log.smcl` per the header convention) and the resulting `.dta` / `.tex` / `.pdf` outputs.
3. If a script fails, halt — do NOT auto-fix unless the failure is trivial (typo flagged by Stata at parse time). For substantive failures (insufficient observations, singular matrices, missing covariates), surface to the user.

For long-running scripts (> 2 minutes), use the **Monitor tool** to stream stdout — same pattern documented in `/data-analysis-r` and `/audit-reproducibility`.

### Phase 3: Verify

1. Confirm every expected output exists in `scripts/stata/_outputs/`.
2. Check `sessionInfo.txt` was captured (package versions).
3. Run `/audit-reproducibility` if a manuscript exists — it now handles Stata `.dta` outputs via `haven`/`pyreadstat` (Pass 4.3).
4. Report scripts run, outputs produced, any warnings from Stata.

### Phase 4: Auto cross-check (mandatory unless opted out)

After the **final specifications** in `03_analyze.do` run, invoke [`/cross-check`](../cross-check/SKILL.md) on each headline result, targeting the project's **cross-check language role** (CLAUDE.md "Project Language Roles"). It re-implements the spec independently in that language — any Python ↔ Stata ↔ R pair — and compares coef/SE/N against the `replication-protocol.md` tolerances, naming the usual culprits on divergence (clustering df, FE/singleton handling, default SE type, seed/sort, logit vs probit PS). A DIVERGENT verdict (out of tolerance, no named culprit) blocks the verify phase — do not present the result as verified.

Skip when:
- `--no-crosscheck` was passed (quick exploratory runs);
- the work lives under `explorations/` (fast-track threshold applies by default).

If `--from-r` was set, the existing R pipeline at `scripts/R/` *is* the cross-check counterpart — `/cross-check` compares against it directly instead of writing a fresh `90_crosscheck` script.

### Phase 5: Review

1. Launch the `stata-reviewer` agent on every `.do` file emitted or modified by this run (same contract as `/review-stata`): *"Review scripts/stata/[name].do against stata-code-conventions.md."* If an analysis plan exists, include its path and the spec IDs the script implements in the dispatch — the reviewer checks the code against the **plan rows**, not the script's self-written header.
2. Address Critical and High findings before presenting results — same gate as the R and Python siblings' review phases.

## Companion skills

- [`/data-analysis-r`](../data-analysis-r/SKILL.md) — R analogue. Same pipeline shape, different language.
- [`/data-analysis-python`](../data-analysis-python/SKILL.md) — Python analogue; in mixed pipelines it produces the `.dta` handoff this skill estimates from.
- [`/cross-check`](../cross-check/SKILL.md) — the Phase 4 independent re-implementation (any Python ↔ Stata ↔ R pair; `--data` mode for prep verification).
- [`/audit-reproducibility`](../audit-reproducibility/SKILL.md) — reads both `.rds` and `.dta` outputs. Cross-checks manuscript claims against the produced values. Updated in v1.9.0 to handle Stata outputs.
- [`/review-paper`](../review-paper/SKILL.md) — if the paper exists and cites tables/figures produced by this pipeline, `/review-paper` auto-invokes `/audit-reproducibility` (per `cross-artifact-review.md`).

## Important

- **Reproduce, don't guess.** If the user specifies a spec, run exactly that.
- **Show your work.** Present the descriptives (`02_descriptive.do` output) before the estimates.
- **Use relative paths; no hardcoded values.** Globals for sample restrictions, date ranges, etc.

## Anti-patterns

- **Hand-editing `.dta` files.** Never. All transformations happen via the `.do` files; `.dta` outputs are derived and reproducible.
- **Skipping the `99_run_all.do`.** This is the AEA-mandated one-command entry point. Build it even for small projects.
- **Using `, robust` by default.** Use `, cluster(id)` at the appropriate level — see `stata-code-conventions.md` §6.
- **Hand-formatting tables in LaTeX.** Use `esttab` and `\input{}` — see `stata-code-conventions.md` §4.
- **Re-running estimation inside the tables script.** `03_analyze.do` ends with `estimates save`; `05_tables_figures.do` starts with `estimates use` — the Stata twin of saveRDS/pickle persistence.
- **Pinning Stata version in only one .do file.** Every `.do` file starts with `version 18` per the convention.

## Cross-references

- [`.claude/rules/stata-code-conventions.md`](../../rules/stata-code-conventions.md) — the discipline contract.
- [`.claude/rules/replication-protocol.md`](../../rules/replication-protocol.md) — tolerance thresholds (applies across R / Stata / Python).
- [stata-mcp on GitHub](https://github.com/SepineTam/stata-mcp) — the MCP server this skill depends on.
- [AEA Data Editor checklist](https://aeadataeditor.github.io/) — replication-package standards.

## Long-running fits / batch reruns: use the Monitor tool (Apr 2026)

Long Stata fits (multi-hour bootstrap with `cluster bootstrap`, large `reghdfe` with millions of observations, simulation studies) should be background-launched and tailed with the Monitor tool — same pattern as `/data-analysis-r` and `/audit-reproducibility` for R / Python. The .do file logs to SMCL; the Monitor tool follows stderr so Claude can react to errors mid-stream.
