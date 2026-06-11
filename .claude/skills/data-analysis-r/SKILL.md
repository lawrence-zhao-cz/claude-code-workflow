---
name: data-analysis-r
description: End-to-end R data analysis pipeline — exploration → cleaning (with validation assertions) → estimation → publication-ready tables and figures. The R member of the analysis triad (/data-analysis-python, /data-analysis-stata); R is this project's default cross-check language. Use when user says "analyze this in R", "run a regression on X", "explore this CSV", "full analysis workflow", "fixest/modelsummary analysis", or points at a `.csv`/`.rds`/`.dta` and asks for R results. Produces numbered R scripts in `scripts/R/` and outputs to `scripts/R/_outputs/`.
argument-hint: "[dataset path or description of analysis goal] [--prep-only] [--no-crosscheck] [--no-execute]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task", "Monitor"]
---

# R Data Analysis Workflow

Run an end-to-end analysis in R: load, explore, clean (with validation), estimate, and produce publication-ready output.

**Input:** `$ARGUMENTS` — a dataset path (e.g., `data/county_panel.csv`) or a description of the analysis goal (e.g., "regress wages on education with state fixed effects using CPS data").

---

## Constraints

- **Follow R code conventions** in `.claude/rules/r-code-conventions.md`
- **Save all scripts** to `scripts/R/` with descriptive names
- **Save all outputs** (figures, tables, RDS) to `scripts/R/_outputs/`
- **Use `saveRDS()`** for every computed object — Quarto slides may need them
- **Use project theme** for all figures (check for custom theme in `.claude/rules/`)
- **Run r-reviewer** on the generated script before presenting results
- **Respect the project's language roles** (CLAUDE.md "Project Language Roles"): if R is the *prep* language and another language estimates, produce the cleaned-data handoff (`.parquet` via `arrow` / `.dta` via `haven`) and stop before estimation. `--prep-only` forces this stop regardless of roles.

---

## Workflow Phases

### Phase 0: Pre-Flight Report

**Before writing any analysis code, produce a Pre-Flight Report** showing you read the inputs. This prevents the common failure mode where the agent hallucinates variable names or skips project conventions.

Output block (in your response to the user, before Phase 1):

```markdown
## Pre-Flight Report

**Dataset:** [path]
- Variables found: [list from head()/names()]
- Rows: [count]
- Key types: [e.g., "outcome=numeric, treatment=binary, state=factor"]
- Missing-data summary: [% missing per key var]

**Language roles (from CLAUDE.md):** prep=[..] estimate=[..] cross-check=[..]

**Project conventions read:**
- `.claude/rules/r-code-conventions.md` — [one-line summary of most relevant rule]
- `.claude/rules/content-invariants.md` — [INV-9, INV-10, INV-11, INV-12 applicable]

**Task interpretation:** [one sentence restating what the user asked for]

**Plan:** [3-5 bullet outline of the R script structure]
```

If any input cannot be read (missing file, unreadable format), stop and ask the user before proceeding.

### Phase 1: Setup and Data Loading

1. Create R script with proper header (title, author, purpose, inputs, outputs)
2. Load required packages at top (`library()`, never `require()`)
3. Set seed once at top in YYYYMMDD format (per `r-code-conventions.md`), e.g. `set.seed(20260415)` (INV-9)
4. Load and inspect the dataset

### Phase 2: Exploratory Data Analysis

Generate diagnostic outputs:
- **Summary statistics:** `summary()`, missingness rates, variable types
- **Distributions:** Histograms for key continuous variables
- **Relationships:** Scatter plots, correlation matrices
- **Time patterns:** If panel data, plot trends over time
- **Group comparisons:** If treatment/control, compare pre-treatment means

Save all diagnostic figures to `scripts/R/_outputs/diagnostics/`.

### Phase 3: Cleaning + Validation

Produce the cleaned frame in `02_clean.R`, then **end the script with explicit validation assertions** (the R twin of `python-code-conventions.md` §7 — fail loud at clean time, never silently downstream):

```r
stopifnot(!anyDuplicated(df$id))                       # key uniqueness
stopifnot(nrow(df) == EXPECTED_N)                      # row count
stopifnot(all(dplyr::between(df$share, 0, 1)))         # value ranges
stopifnot(nrow(dplyr::anti_join(a, b, by = "id")) == 0)  # merge match rate
print(sort(colMeans(is.na(df)), decreasing = TRUE))    # missingness snapshot
```

Persist the cleaned data (`saveRDS()`; also `.parquet` via `arrow` or `.dta` via `haven` if it hands off to another language per the handoff convention in `replication-protocol.md`).

**If `--prep-only` was passed (or the language roles assign estimation elsewhere), stop here and report** — the handoff file is the deliverable.

### Phase 4: Main Analysis (Estimation)

Based on the research question:
- **Regression analysis:** Use `fixest` for panel data, `lm`/`glm` for cross-section
- **Standard errors:** Cluster at the appropriate level (document why)
- **Multiple specifications:** Start simple, progressively add controls
- **Effect sizes:** Report standardized effects alongside raw coefficients
- **Diagnostics before trusting a spec:** multicollinearity, influential outliers, perfect prediction/separation

### Phase 4b: Auto cross-check (mandatory unless opted out)

After the **final specifications** are estimated, invoke [`/cross-check`](../cross-check/SKILL.md) on each headline result, targeting the project's **cross-check language role** (CLAUDE.md "Project Language Roles"). A DIVERGENT verdict (out of tolerance, no named culprit) blocks Phase 6 — do not present the result as verified.

Skip when:
- `--no-crosscheck` was passed (quick exploratory runs);
- the work lives under `explorations/` (fast-track threshold applies by default);
- the result is an intermediate spec, not a headline estimate (cross-check final specs only).

### Phase 5: Publication-Ready Output

**Tables:**
- Use `modelsummary` for regression tables (preferred) or `stargazer`
- Include all standard elements: coefficients, SEs, significance stars, N, R-squared
- Export as `.tex` for LaTeX inclusion and `.html` for quick viewing

**Figures:**
- Use `ggplot2` with project theme
- Set `bg = "transparent"` for Beamer compatibility
- Include proper axis labels (sentence case, units)
- Export with explicit dimensions: `ggsave(width = X, height = Y)`
- Save as both `.pdf` and `.png`

### Phase 6: Save and Review

1. `saveRDS()` for all key objects (regression results, summary tables, processed data)
2. Create `scripts/R/_outputs/` subdirectories as needed with `dir.create(..., recursive = TRUE)`
3. Run the r-reviewer agent on the generated script:

```
Delegate to the r-reviewer agent:
"Review the script at scripts/R/[script_name].R"
```

4. Address any Critical or High issues from the review.

---

## Pipeline Structure

**Default: the numbered pipeline** — the shape the rest of the repo already assumes for R (`replication-protocol.md` and `/audit-reproducibility` both invoke `Rscript scripts/R/00_run_all.R`), mirroring the Python and Stata siblings:

```
scripts/R/
├── 00_run_all.R         # source()s 01..05 in order; the one-command entry point
├── 01_load.R            # raw → in-memory / interim
├── 02_clean.R           # cleaning + the validation assertions (Phase 3)
├── 03_analyze.R         # estimation (fixest / lm / glm); saveRDS every fit
├── 04_tables.R          # modelsummary → .tex (+ .html quick view); loads .rds, never re-fits
├── 05_figures.R         # ggplot2 → .pdf + .png; loads .rds
└── _outputs/            # all generated artifacts
```

**Small/exploratory jobs** may instead use a single script with numbered section comments — the template below. Graduate it to the numbered pipeline once results feed a paper or deck.

`--no-execute` scaffolds the scripts without running them (dry run — same lever as the Stata sibling); useful for reviewing the pipeline shape before a long run.

```r
# ============================================================
# [Descriptive Title]
# Author: [from project context]
# Purpose: [What this script does]
# Inputs: [Data files]
# Outputs: [Figures, tables, RDS files]
# ============================================================

# 0. Setup ----
library(tidyverse)
library(fixest)
library(modelsummary)

set.seed(20260415)  # YYYYMMDD per r-code-conventions.md (INV-9)

dir.create("scripts/R/_outputs/analysis", recursive = TRUE, showWarnings = FALSE)

# 1. Data Loading ----
# [Load and clean data]

# 2. Exploratory Analysis ----
# [Summary stats, diagnostic plots]

# 3. Main Analysis ----
# [Regressions, estimation]

# 4. Tables and Figures ----
# [Publication-ready output]

# 5. Export ----
# [saveRDS for all objects, ggsave for all figures]
```

---

## Companion skills

- [`/data-analysis-python`](../data-analysis-python/SKILL.md) (Python) · [`/data-analysis-stata`](../data-analysis-stata/SKILL.md) (Stata) — same pipeline shape, different language; pick per project via the language-roles table in `CLAUDE.md`.
- [`/cross-check`](../cross-check/SKILL.md) — the Phase 4b independent re-implementation (also has a `--data` mode for high-stakes prep).
- [`/review-r`](../review-r/SKILL.md) — code review · [`/audit-reproducibility`](../audit-reproducibility/SKILL.md) — numeric verification.

---

## Important

- **Halt on failures — never auto-fix substantive errors.** If a script errors, stop; fix only trivial parse-time typos and re-run. Substantive failures (non-convergence, singular matrices, missing covariates, dropped observations) are surfaced to the user, never silently patched — same discipline as the Stata sibling's execute phase.
- **Reproduce, don't guess.** If the user specifies a regression, run exactly that.
- **Show your work.** Print summary statistics before jumping to regression.
- **Check for issues.** Look for multicollinearity, outliers, perfect prediction.
- **Use relative paths.** All paths relative to repository root.
- **No hardcoded values.** Use variables for sample restrictions, date ranges, etc.

## Anti-patterns

- **Re-fitting models in the table/figure scripts.** `saveRDS()` once in `03_analyze.R`; load downstream.
- **Hand-formatting tables in LaTeX.** Emit `.tex` from `modelsummary`/`stargazer`.
- **Skipping the validation assertions.** `02_clean.R` must end with the Phase 3 battery.
- **`require()` instead of `library()`.** `require()` fails silently; `library()` fails loud (conventions rule).

## Long-running fits: use the Monitor tool (Apr 2026)

For regressions, simulations, or bootstrap loops that take more than a couple of minutes, launch via Bash with `run_in_background: true` and then use Anthropic's **Monitor tool** to stream R stdout into the conversation in real time. Pattern:

1. Background-launch: `Rscript scripts/R/03_analyze.R` with `run_in_background: true`. Capture the `bash_id`.
2. Use Monitor on the `bash_id` until a milestone fires (e.g., `Coefficients table written`, or process exit).
3. Continue or course-correct based on what the stream reveals.

This avoids the polling-loop anti-pattern (`sleep 30; check; sleep 30; check`) and avoids burning cache on idle waits. Especially useful when paired with the [Cost-Conscious Parallelism](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#cost-conscious-parallelism) section of the guide.
