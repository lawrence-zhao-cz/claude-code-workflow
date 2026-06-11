---
paths:
  - "scripts/**/*.R"
  - "scripts/**/*.py"
  - "scripts/**/*.do"
  - "Figures/**/*.R"
---

# Replication-First Protocol

**Core principle:** Replicate original results to the dot BEFORE extending.

---

## Phase 1: Inventory & Baseline

Before writing any analysis code (in whichever language the project's roles assign):

- [ ] Read the paper's replication README
- [ ] Inventory replication package: language, data files, scripts, outputs
- [ ] Record gold standard numbers from the paper:

```markdown
## Replication Targets: [Paper Author (Year)]

| Target | Table/Figure | Value | SE/CI | Notes |
|--------|-------------|-------|-------|-------|
| Main ATT | Table 2, Col 3 | -1.632 | (0.584) | Primary specification |
```

- [ ] Store targets in `quality_reports/LectureNN_replication_targets.md` or as RDS

---

## Phase 2: Translate & Execute

- [ ] Follow the language's conventions rule — `r-code-conventions.md` (R), `python-code-conventions.md` (Python), `stata-code-conventions.md` (Stata)
- [ ] Translate line-by-line initially -- don't "improve" during replication
- [ ] Match original specification exactly (covariates, sample, clustering, SE computation)
- [ ] Save all intermediate results in the producing language's format — `.rds` (R), `.parquet`/pickle (Python), `.dta` (Stata) — per the Cross-Language Handoff Convention below

### Stata to R Translation Pitfalls

<!-- Customize: Add pitfalls specific to your field -->

| Stata | R | Trap |
|-------|---|------|
| `reg y x, cluster(id)` | `feols(y ~ x, cluster = ~id)` | Stata clusters df-adjust differently from some R packages |
| `areg y x, absorb(id)` | `feols(y ~ x \| id)` | Check demeaning method matches |
| `probit` for PS | `glm(family=binomial(link="probit"))` | R default logit != Stata default in some commands |
| `bootstrap, reps(999)` | Depends on method | Match seed, reps, and bootstrap type exactly |

### Stata to Python Translation Pitfalls

| Stata | Python | Trap |
|-------|--------|------|
| `if x > 100` | `df[df.x > 100]` | **Stata `.` sorts as +∞** — the Stata filter *keeps* missings, pandas drops NaN → N diverges before any estimation |
| `reghdfe y x, absorb(id year) cluster(id)` | `pyfixest.feols("y ~ x \| id + year", vcov={"CRV1": "id"})` | Singleton-group handling and small-sample df adjustments can differ — check both packages' settings |
| `merge 1:1 id using b, assert(3)` | `pd.merge(..., indicator=True)` + assert | pandas has no `assert()` arg — replicate the match-rate assertion explicitly (the §7 battery) |
| `aweight` / `fweight` / `pweight` | `weights=` kwarg | Weight *types* differ; confirm which normalization the Python estimator applies |
| `i.x` factor expansion | `C(x)` / `pd.get_dummies` | Reference-level choice can differ — fix the omitted category explicitly on both sides |
| Date constants | `pd.Timestamp` | Stata's epoch is 1960-01-01; Unix/pandas is 1970-01-01 — off-by-3653-days on raw numeric dates |
| `probit` for PS | `statsmodels` default | Match link functions explicitly (logit vs probit) |

### Python to R Translation Pitfalls

| Python | R | Trap |
|--------|---|------|
| `pyfixest.feols(...)` | `fixest::feols(...)` | Closest pair available (same lineage) — divergence here usually means data, not estimator: check the handoff file is current |
| `NaN` | `NA` | `NaN == NaN` is False in both, but aggregation defaults differ (`skipna=True` in pandas vs `na.rm = FALSE` in R) — state both explicitly |
| `pd.Categorical` order | `factor()` levels | Reference level: pandas takes first observed/declared, R takes first alphabetical — set explicitly on both sides |
| `np.random.default_rng(seed)` | `set.seed(seed)` | Different RNG algorithms — identical seeds do NOT give identical draws; compare bootstrap results by tolerance, never by digit |
| Integer division `//` | `%/%` | Negative-operand rounding differs from C-style truncation; avoid in derived variables |
| `read_parquet` dtypes | `arrow::read_parquet` | Parquet round-trips types faithfully — prefer it over CSV (which re-guesses types on every read) |

---

## Cross-Language Handoff Convention

A mixed pipeline (e.g. prep = Python → estimate = Stata → cross-check = R, per the language-roles table in `CLAUDE.md`) keeps its reproducibility chain unbroken by exchanging data **only** through typed, on-disk handoff files in the producing language's `_outputs/` directory:

| Producer | Consumer | Format | Write with | Read with |
|---|---|---|---|---|
| Python | Stata | `.dta` | `pyreadstat.write_dta()` | `use` |
| Python | R | `.parquet` (or `.feather`) | `df.to_parquet()` | `arrow::read_parquet()` |
| Stata | Python / R | `.dta` | `save` | `pyreadstat.read_dta()` / `haven::read_dta()` |
| R | Python | `.parquet` | `arrow::write_parquet()` | `pd.read_parquet()` |
| R | Stata | `.dta` | `haven::write_dta()` | `use` |

Rules:

- **Never exchange via CSV** — type re-guessing on read silently corrupts dtypes, dates, and leading-zero IDs.
- **The handoff file is a derived artifact** — regenerate it from the producing script whenever that script changes (a cross-check against a stale handoff verifies nothing).
- **Value labels / categoricals:** `.dta` carries value labels; parquet carries categoricals. Confirm the consumer decodes them the same way the producer encoded them (labeled integers vs strings is a classic silent divergence).
- **One direction per dataset.** A file is written by exactly one script in one language; consumers only read. Mirrors the "single source of truth" principle.

---

## Phase 3: Verify Match

### Tolerance Thresholds

| Type | Tolerance | Rationale |
|------|-----------|-----------|
| Integers (N, counts) | Exact match | No reason for any difference |
| Point estimates | < 0.01 | Rounding in paper display |
| Standard errors | < 0.05 | Bootstrap/clustering variation |
| P-values | Same significance level | Exact p may differ slightly |
| Percentages | < 0.1pp | Display rounding |

### If Mismatch

**Do NOT proceed to extensions.** Isolate which step introduces the difference, check common causes (sample size, SE computation, default options, variable definitions), and document the investigation even if unresolved. To localize *which* step drifted, hand off to [`/diagnose`](../skills/diagnose/SKILL.md) (reproduce → minimise → bisect the pipeline) — it is the single-claim root-cause counterpart to `/audit-reproducibility`'s whole-paper check.

**The mismatch does not presume the code is correct.** The on-disk output is a *challenger*, not an oracle — a refactor may have broken a previously-correct table, so the *manuscript* number may be the right one and the code the stale/buggy side. Frame it as "one of {paper, code} must change — isolate which," never "revert the code to match the paper."

**A defensible alternative is not a failure.** If the gap is explained by a *concrete, named alternative specification* (e.g. never-treated vs not-yet-treated comparison group, conditional vs unconditional parallel trends, `reghdfe` vs `feols` clustering df, MC seed/reps, display rounding), record that named alternative and mark the claim **EXPLAINED** rather than FAIL — see the `status` semantics below. A blank or vague note ("unclear") never downgrades a FAIL.

### Replication Report

Save to `quality_reports/LectureNN_replication_report.md`:

```markdown
# Replication Report: [Paper Author (Year)]
**Date:** [YYYY-MM-DD]
**Original language:** [Stata/R/Python/etc.]
**Translation:** [script path] (language: [R/Python/Stata])

## Summary
- **Targets checked / Passed / Failed:** N / M / K
- **Overall:** [REPLICATED / PARTIAL / FAILED]

## Results Comparison

| Target | Paper | Ours | Diff | Status |
|--------|-------|------|------|--------|

## Discrepancies (if any)
- **Target:** X | **Investigation:** ... | **Resolution:** ...

## Environment
- R version, key packages (with versions), data source
```

---

## Phase 4: Only Then Extend

After replication is verified (all targets PASS):

- [ ] Commit replication script: "Replicate [Paper] Table X -- all targets match"
- [ ] Now extend with course-specific modifications (different estimators, new figures, etc.)
- [ ] Each extension builds on the verified baseline

---

## Enforcement

This rule is enforced at three layers:

**Per intent, before any code** — the [`/analysis-plan`](../skills/analysis-plan/SKILL.md) document (`scripts/analysis_plans/<slug>.md`) is the user-approved specification: the pipelines execute it by ID, the reviewers check code against its rows, `/cross-check` re-implements from it, and the `plan-auditor` verifies it against the user's verbatim words.

**Per result, continuously** — the [`/cross-check`](../skills/cross-check/SKILL.md) skill re-implements a result (or, with its `--data` mode, a cleaned dataset) independently in a second language (any Python ↔ Stata ↔ R pair) and compares against the tolerance thresholds above. `/data-analysis-python` and `/data-analysis-stata` invoke it automatically after estimation, targeting the project's cross-check language role; opt out per run with their `--no-crosscheck` flag (exploratory work in `explorations/` is exempt by default).

**Per manuscript, before submission** — the [`/audit-reproducibility`](../skills/audit-reproducibility/SKILL.md) skill parses numeric claims from a manuscript, locates matching values in `scripts/R/_outputs/` (or the user-specified outputs directory), and compares against the tolerance thresholds above. Run it:

- **Before submission** — `/audit-reproducibility path/to/manuscript.tex`
- **Before releasing a replication package** — same invocation; aim for zero FAILs.
- **As a pre-commit gate** — wire into `/commit` when the diff touches both manuscript and analysis files.

The skill exits 1 on any tolerance violation, so it integrates cleanly with quality gates.

---

## Claims Provenance: `passport.yaml`

A passport is a single per-paper, per-branch YAML file at `quality_reports/passports/<paper-slug>.yaml` that records, for each verified numeric claim in the manuscript, the script invocation and output file that produced it. The contract is intentionally narrow: numeric claims only (point estimates, standard errors, p-values, sample sizes, percentages from tables/figures), not prose claims (which `/verify-claims` handles separately).

`templates/passport-template.yaml` is the starter file. Forkers should copy it once per paper.

### Schema

```yaml
paper:
  slug: <paper-slug>                              # used in filename + report headings
  title: <full paper title>
  branch: <git branch on which this passport is current>
  last_audit: <ISO-8601 timestamp>
  last_audit_by: "/audit-reproducibility"         # or human, or another skill

claims:
  - id: C1                                        # stable identifier (used in cross-references)
    claim: "ATT = -1.632 (SE 0.584, N=4291)"     # exact text or paraphrase from manuscript
    location: "manuscript.tex:Table 2, Col 3"     # where it appears in the paper
    source_file: scripts/R/03_analyze.R           # script that produced the value
    source_line: 147                              # nearest line in the script
    output_file: scripts/R/_outputs/main_did.rds  # where the value lives on disk
    output_field: att_overall                      # field within the output (e.g., list element, column)
    tolerance:
      point_estimate: 0.01                         # absolute tolerance per Phase 3 above
      standard_error: 0.05
      n: exact
    last_verified_on: <ISO-8601>
    last_verified_by: "/audit-reproducibility"
    status: PASS                                   # PASS | FAIL | EXPLAINED | STALE | UNVERIFIED
    notes: |
      Optional notes — e.g., "matches paper to 3 decimals; SE differs in 4th
      decimal due to clustering df adjustment, within tolerance."
      To downgrade a FAIL to EXPLAINED, this field MUST name a concrete
      alternative spec, e.g. "never-treated vs not-yet-treated comparison
      group; under not-yet-treated the published −1.19 matches the script."
```

### `status` semantics

- **PASS** — last audit confirmed the claim within tolerance.
- **FAIL** — last audit detected a discrepancy outside tolerance **and** no concrete named alternative is recorded in `notes`. Blocks `/commit` for the affected files unless explicit override.
- **EXPLAINED** — outside tolerance, **but** `notes` records a *specific named alternative specification* that accounts for the gap (defensible alternative, paper-corrected, or code-corrected). Surfaced in the audit report and meant to flow into a response-to-referees; does **not** block. The hard floor holds: an UNMATCHED claim or a note without a named alternative stays FAIL — `/audit-reproducibility` never downgrades on a blank or vague note.
- **STALE** — the underlying `source_file` or `output_file` was modified after `last_verified_on`. Re-run `/audit-reproducibility` to refresh.
- **UNVERIFIED** — the claim was added to the manuscript but never run through `/audit-reproducibility`. Should not appear in a submission-ready passport.

### Integration

- **`/audit-reproducibility`** reads the passport at start, writes back after every claim audit. Failed claims are reported with their `id` and `location` so the author can find them in the manuscript instantly.
- **`/commit`** reads the passport when a diff touches both `manuscript.tex` (or .qmd) and any `source_file` listed. If the passport contains any FAIL or STALE for a claim whose `source_file` is in the diff, `/commit` halts (advisory by default; gate-refuse if `--strict-passport` is set in `.claude/settings.json`). **EXPLAINED claims do not halt** — the author has already recorded a defensible named alternative.
- **`/review-paper`** (default mode + `--peer`) appends a summary section to its report when the passport exists: `claims: N total, PASS: A, FAIL: B, EXPLAINED: E, STALE: C, UNVERIFIED: D`. Editors and referees know whether numeric claims have been independently verified at draft time — and EXPLAINED rows tell them which contested numbers already carry a documented justification.

### Inspiration

The pattern is borrowed from [Imbad0202/academic-research-skills](https://github.com/Imbad0202/academic-research-skills)'s "Material Passport" concept (a YAML state-file threaded through their pipeline). Their schema is heavier (13 contracts, threaded through ~6 agents); ours is deliberately scoped to numeric-claim provenance only. Forkers who need broader provenance tracking can extend the schema or vendor ARS's design directly.

### Anti-patterns

- **Do not auto-populate** the passport at `/audit-reproducibility` time without showing the user the inferred mapping. Source-line inference is best-effort; the author confirms.
- **Do not promote UNVERIFIED claims to PASS** without running the actual numeric audit. The passport is a verified-state artifact; bypassing the verification defeats the purpose.
- **Do not use the passport as a substitute for `/verify-claims`.** The passport handles numeric claims with code provenance; `/verify-claims` handles citation and named-entity claims with literature provenance. Both run.
