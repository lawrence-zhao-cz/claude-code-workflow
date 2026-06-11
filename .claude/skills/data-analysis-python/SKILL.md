---
name: data-analysis-python
description: End-to-end Python data analysis pipeline — exploration → cleaning (with a validation battery) → estimation → publication-ready tables and figures. The Python analogue of /data-analysis-r (R) and /data-analysis-stata (Stata); the default for prep-heavy work. Use when user says "analyze this in Python", "run a regression in Python", "explore this CSV/parquet", "pandas analysis", "statsmodels/linearmodels/pyfixest regression", or points at data and wants Python results. Produces numbered .py scripts in scripts/python/ with outputs in scripts/python/_outputs/.
argument-hint: "[dataset path or description of analysis goal] [--prep-only] [--no-crosscheck] [--no-execute]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task", "Monitor"]
---

# Python Data Analysis Workflow

Run an end-to-end analysis in Python: load, explore, clean (with validation), estimate, and produce publication-ready output.

**Input:** `$ARGUMENTS` — a dataset path (e.g. `data/county_panel.parquet`) or an analysis goal (e.g. "regress wages on education with state and year fixed effects, clustered by state").

---

## Constraints

- **Follow [`.claude/rules/python-code-conventions.md`](../../rules/python-code-conventions.md)** — uv, `np.random.default_rng` seeded once, `pathlib`, numbered pipeline, numerical discipline.
- **Save scripts** to `scripts/python/` with numbered descriptive names; **outputs** to `scripts/python/_outputs/`.
- **Persist every computed object** (pickle/joblib fitted results, `.parquet` cleaned data) — table/figure scripts load pre-computed objects, never re-fit.
- **Use the project palette** for figures (transparent bg, `.pdf` + `.png`).
- **Run the `python-reviewer` agent** on generated scripts before presenting results.
- **Respect the project's language roles** (CLAUDE.md "Project Language Roles"): if Python is the *prep* language and Stata the *estimation* language, this skill produces the cleaned-data handoff (`.dta`/`.parquet`) and stops before estimation. `--prep-only` forces this stop regardless of roles — the explicit "data cleaning only" entry point (Phases 0–3, ending with the validation battery + handoff export).
- **Halt on failures — never auto-fix substantive errors.** If a script errors, stop; fix only trivial parse-time typos and re-run. Substantive failures (non-convergence, singular matrices, missing covariates, dropped observations) are surfaced to the user, never silently patched.
- **Reproduce, don't guess; show your work.** If the user specifies a spec, run exactly that; print/inspect summaries before presenting estimates.
- `--no-execute` scaffolds the numbered scripts without running them (dry run — same lever as the R and Stata siblings).

---

## Workflow Phases

### Phase 0: Pre-Flight Report

Before writing any code, produce a Pre-Flight Report proving you read the inputs (prevents hallucinated variable names / skipped conventions):

```markdown
## Pre-Flight Report
**Dataset:** [path]
- Variables: [from df.columns / df.dtypes]
- Rows: [count]   Key types: [outcome=float, treat=int8, state=category]
- Missingness: [% missing per key var]
**Language roles (from CLAUDE.md):** prep=[..] estimate=[..] cross-check=[..]
**Conventions read:** python-code-conventions.md — [most relevant rule]
**Task interpretation:** [one sentence]
**Plan:** [3–5 bullet outline of the script structure]
```

If an input can't be read, stop and ask before proceeding.

### Phase 1: Setup & Loading
Header (per conventions), imports at top, `SEED` + `rng = np.random.default_rng(SEED)`, build `OUT = Path("scripts/python/_outputs"); OUT.mkdir(parents=True, exist_ok=True)`. Load and inspect (`df.info()`, `df.describe()`, dtypes).

### Phase 2: Exploratory Data Analysis
Summary statistics, missingness rates, distributions for key continuous vars, relationships (correlations/scatter), time patterns if panel, pre-treatment group comparisons if treatment/control. Save diagnostics to `_outputs/diagnostics/`.

### Phase 3: Cleaning + Validation Battery
Produce the cleaned frame, then **end `02_clean.py` with the validation battery** (`python-code-conventions.md` §7): key uniqueness, merge match rates, row counts, value ranges, missingness snapshot — assertions that fail loud. Persist cleaned data (`.parquet`; also `.dta` via `pyreadstat` if it hands off to Stata). **If `--prep-only` was passed (or the language roles assign estimation elsewhere), stop here and report** — the handoff file is the deliverable.

### Phase 4: Estimation
- Panel/FE/IV → `pyfixest` (`feols`) or `linearmodels`; general → `statsmodels`; ML-causal → `econml`/`doubleml`.
- **Clustered SEs at the assignment level, documented.** Start simple, add controls progressively across specs.
- **Effect sizes:** report standardized effects alongside raw coefficients where meaningful.
- **Diagnostics before trusting a spec:** multicollinearity, influential outliers, perfect prediction/separation.
- Pickle fitted results to `_outputs/`.

### Phase 4b: Auto cross-check (mandatory unless opted out)

After the **final specifications** are estimated, invoke [`/cross-check`](../cross-check/SKILL.md) on each headline result, targeting the project's **cross-check language role** (CLAUDE.md "Project Language Roles"). The cross-check re-implements the spec independently in that language and compares coef/SE/N against the `replication-protocol.md` tolerances; a DIVERGENT verdict (out of tolerance, no named culprit) blocks Phase 6 — do not present the result as verified.

Skip when:
- `--no-crosscheck` was passed (quick exploratory runs);
- the work lives under `explorations/` (fast-track threshold applies by default);
- the result is an intermediate spec, not a headline estimate (cross-check final specs only — each check doubles the estimation cost).

### Phase 5: Publication Output
- **Tables:** emit `.tex` from the estimation (`pyfixest .etable`, `statsmodels.summary_col`, `stargazer`, or `pystout`) for `\input{}`. Coeffs, SEs, stars (`* .10 ** .05 *** .01`), N, R².
- **Figures:** matplotlib, `transparent=True`, explicit `figsize`, project palette, `.pdf` + `.png`.

### Phase 6: Review
1. Confirm every expected output exists in `_outputs/`.
2. Launch the `python-reviewer` agent: *"Review scripts/python/[name].py against python-code-conventions.md."*
3. Address Critical/High findings before presenting.

---

## Long-running fits: use the Monitor tool

For fits/bootstraps/simulations over a couple of minutes, background-launch (`uv run python scripts/python/03_analyze.py`, `run_in_background: true`), capture the `bash_id`, and stream with the **Monitor tool** until a milestone (e.g. `tables written`) or process exit — avoids the `sleep; check` polling anti-pattern. Same pattern as `/data-analysis-r` and `/data-analysis-stata`.

## Companion skills
- [`/data-analysis-r`](../data-analysis-r/SKILL.md) (R) · [`/data-analysis-stata`](../data-analysis-stata/SKILL.md) (Stata) — same pipeline shape, different language.
- [`/cross-check`](../cross-check/SKILL.md) — the Phase 4b independent re-implementation (also has a `--data` mode for high-stakes prep).
- [`/review-python`](../review-python/SKILL.md) — code review · [`/audit-reproducibility`](../audit-reproducibility/SKILL.md) — numeric verification.

## Anti-patterns
- **Re-fitting models in the table/figure scripts.** Pickle once in `03_analyze.py`; load downstream.
- **`np.random.seed()` / chained assignment / `pd.concat` in a loop.** See conventions §8.
- **Hand-formatting tables in LaTeX.** Emit `.tex` from the fit.
- **Skipping the validation battery.** `02_clean.py` must end with assertions.
