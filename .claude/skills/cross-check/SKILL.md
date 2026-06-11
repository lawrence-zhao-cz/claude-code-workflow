---
name: cross-check
description: Independently re-run a result in a second language — any Python ↔ Stata ↔ R pair — and compare coefficients/SEs/N (or, with --data, two independently produced cleaned datasets cell-by-cell) against the replication-protocol.md tolerances; on divergence, name the usual culprits (clustering df, FE/singleton handling, default SE type, seed/sort order, missing-value filters). Use when user says "cross-check this regression", "re-run this in Stata/R/Python", "independent re-implementation", "verify the prep in a second language", "do the numbers match across languages", or as the automatic post-estimation step of /data-analysis-python and /data-analysis-stata. Runs Python via uv, Stata via the stata-mcp MCP server, R via Rscript.
argument-hint: "[result-or-dataset pointer] [target-language] [--data]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task", "Monitor"]
effort: high
---

# `/cross-check` — independent re-implementation in a second language

Take a result produced in one language and reproduce it **independently** in another, then compare numerically against the tolerance contract in [`.claude/rules/replication-protocol.md`](../../rules/replication-protocol.md). This is the per-result half of continuous replication: [`/audit-reproducibility`](../audit-reproducibility/SKILL.md) checks that the *manuscript* matches the *outputs*; this skill checks that the *outputs* survive an independent re-implementation.

Generalizes `/data-analysis-stata --from-r` (which compared one fixed pair) to **any Python ↔ Stata ↔ R pair**, in either direction.

## Two modes

| Mode | Compares | Typical trigger |
|---|---|---|
| **Result mode** (default) | A fitted result (coefficients, SEs, N) vs. its re-estimation in the target language | After estimation — automatically from `/data-analysis-python` / `/data-analysis-stata`, or on request |
| **`--data` mode** | Two independently produced cleaned datasets, cell-by-cell | High-stakes data prep — the second half of "verify the prep is accurate" (the first half is the validation battery in `python-code-conventions.md` §7) |

## Inputs

- `$0` — pointer to the source artifact: a pickled/`.rds` fitted result, an `esttab`/`etable` `.tex`, a `.smcl`/`.log` with stored estimates, or (in `--data` mode) a cleaned dataset (`.parquet` / `.dta` / `.rds`) **or** the cleaning script that produces it.
- `$1` — target language (`python` | `stata` | `r`). If omitted, read the **cross-check role** from the language-roles table in `CLAUDE.md` ("Project Language Roles"); if that is also unset, ask.
- `--data` — dataset-comparison mode (see above).

The source language is inferred from the artifact (`.pickle`/`.parquet` → Python, `.dta`+`.do` provenance → Stata, `.rds` → R). Source and target must differ — a same-language re-run is a reproduction, not a cross-check.

## Independence discipline (what makes this a check, not an echo)

Re-implement from the **specification**, not by transliterating the source script line-by-line:

1. Extract the spec — from the analysis-plan row when one exists (see Phase 0), else from the source artifact and its producing script: outcome, regressors, fixed effects, sample filter, weights, cluster level, SE type, estimator (and, in `--data` mode: raw inputs, merge keys, filters, derived-variable definitions).
2. Write the target-language script **from that spec**, using the target language's *canonical* package — never a hand-rolled estimator (same principle as `/did-event-study`):

   | Estimator | Python | Stata | R |
   |---|---|---|---|
   | OLS / FE / IV | `pyfixest` / `linearmodels` | `reghdfe` / `ivreghdfe` | `fixest` |
   | Staggered DiD | (defer to `/did-event-study`) | `csdid` / `drdid` | `did` / `DRDID` |
   | General MLE/GLM | `statsmodels` | native commands | `glm` / base |

3. Both implementations read the **same handoff file** (see the cross-language handoff convention in `replication-protocol.md`) in result mode — so a divergence isolates the *estimation*, not the prep. In `--data` mode the target script starts from the **raw inputs** instead, so a match validates the prep itself.

## Workflow

### Phase 0: Pre-flight

1. Read `replication-protocol.md` (tolerances + language-pair pitfalls tables) and the language-roles table in `CLAUDE.md`.
2. Verify the target toolchain: Python → `uv` resolves; R → `Rscript --version`; Stata → the `stata-mcp` MCP server is registered (halt with install instructions if not: `claude mcp add stata-mcp --scope user -- uvx stata-mcp`).
3. **Spec-source priority:** if `scripts/analysis_plans/<slug>.md` exists and the result maps to a spec ID, extract the spec **from the plan row** (the user-approved document, per `/analysis-plan`) — both implementations then derive from the *user's* words, making intent errors visible to this skill for the first time. Fall back to the script header otherwise.
4. Read the source artifact and its producing script; emit a one-paragraph **spec summary** (outcome, regressors, FE, cluster, sample, N expected) so the user can catch a mis-extracted spec before any code is written.

### Phase 1: Write the cross-check script

- Script lands in the target language's pipeline directory with a `90_`-prefix so it never collides with the main numbered pipeline: `scripts/python/90_crosscheck_<name>.py`, `scripts/stata/90_crosscheck_<name>.do`, `scripts/R/90_crosscheck_<name>.R`.
- Follows the target language's conventions rule (`python-code-conventions.md` / `stata-code-conventions.md` / `r-code-conventions.md`) — header block, seeded RNG, relative paths.
- Writes its comparison values to `scripts/<lang>/_outputs/crosscheck_<name>.csv` (long format: `parameter, estimate, se, n`) so the comparison step is file-based and re-runnable.

### Phase 2: Execute

- **Python:** `uv run python scripts/python/90_crosscheck_<name>.py`
- **Stata:** dispatch the `.do` file to `stata-mcp`; capture the log.
- **R:** `Rscript scripts/R/90_crosscheck_<name>.R`

For runs over a couple of minutes, background-launch and stream with the **Monitor tool** (same pattern as `/data-analysis-python` and `/data-analysis-stata`). If the script errors, fix trivial issues (typos, paths) and re-run; surface substantive failures (convergence, singularities) to the user — they are themselves evidence of fragility.

### Phase 3: Compare

**Result mode** — apply the `replication-protocol.md` thresholds per parameter:

| Quantity | Tolerance |
|---|---|
| N (and any count) | Exact |
| Point estimates | < 0.01 |
| Standard errors | < 0.05 |
| P-values | Same significance level |

**`--data` mode** — compare the two cleaned datasets:

| Check | Tolerance |
|---|---|
| Row count, key set (sorted) | Exact |
| Integer / categorical / string cells | Exact |
| Float cells | Relative 1e-6 (representation noise only — the prep is deterministic) |
| Missingness pattern per column | Exact |

Compare via a small Python harness (`pandas` + `pyreadstat`/`pyarrow` read both sides) regardless of the pair — one comparator, not three.

### Phase 4: Diagnose divergence (only if out of tolerance)

Walk the **culprit checklist** for the language pair (full tables live in `replication-protocol.md`):

1. **Sample first.** If N differs, stop — nothing downstream is comparable. Usual cause: missing-value semantics in filters (Stata `.` sorts as +∞: `if x > 100` *keeps* missings; pandas/R drop NaN/NA in the same comparison).
2. **Clustering df / small-sample adjustment** — `reghdfe` vs `fixest`/`pyfixest` CRV1 defaults.
3. **FE / singleton handling** — `reghdfe` drops singleton groups iteratively by default; check the equivalent setting in the target package.
4. **Default SE type** — homoskedastic vs HC1 vs cluster; never compare across different vcov choices.
5. **Seed / sort order** — any bootstrap or random step needs the same seed *and* a deterministic sort before draws.
6. **Estimator defaults** — logit vs probit PS, weight types (aweight/fweight vs normalized weights), reference levels for factors.

A divergence **explained by a concrete named culprit** is recorded as **EXPLAINED** (same semantics as `replication-protocol.md` `status`); a blank or vague note never downgrades a DIVERGENT finding. If the culprit can't be named, hand off to [`/diagnose`](../diagnose/SKILL.md) to bisect which step drifts.

### Phase 5: Report

Write `quality_reports/cross_checks/YYYY-MM-DD_<name>.md`:

```markdown
# Cross-Check: [result/dataset name]
**Date:** [YYYY-MM-DD]  **Pair:** [source → target]  **Mode:** [result | data]

## Spec
[the Phase 0 spec summary]

## Comparison
| Parameter | Source | Target | Diff | Tolerance | Status |
|---|---|---|---|---|---|

## Verdict: MATCH / EXPLAINED / DIVERGENT
[If EXPLAINED: the named culprit. If DIVERGENT: checklist findings + /diagnose handoff.]

## Scripts
[source script · 90_crosscheck script · comparison outputs]
```

## Exit behavior

- **MATCH** (all within tolerance) → exit 0.
- **EXPLAINED** (out of tolerance, concrete named culprit recorded) → exit 0 with the culprit surfaced — carry it into the paper's response-to-referees the same way `/audit-reproducibility` carries EXPLAINED claims.
- **DIVERGENT** (out of tolerance, no named culprit) → exit 1. Callers (`/data-analysis-python`, `/data-analysis-stata`) treat this as a blocker: do not present the source result as verified.

## Auto-invocation contract (how the estimation skills call this)

- `/data-analysis-python` and `/data-analysis-stata` invoke this skill **automatically after estimation**, targeting the project's **cross-check language role** from `CLAUDE.md`.
- **Final specifications only** — not every exploratory run (each cross-check doubles the estimation cost).
- Escape hatches: the caller's `--no-crosscheck` flag (e.g. `/data-analysis-python data.parquet --no-crosscheck`), and work under `explorations/` is exempt by default per its fast-track threshold.
- The caller passes the pickled/stored result as `$0`; this skill resolves the target language itself.

## Anti-patterns

- **Transliterating the source script.** A line-by-line port reproduces the source's bugs. Re-implement from the spec.
- **Hand-rolling an estimator in the target language.** Use the canonical package; if none exists for the estimator, say so and stop — a bespoke implementation is not a credible check.
- **Comparing across different vcov choices** and calling the SE "divergent". Match the SE type first, then compare.
- **Cross-checking against a stale handoff file.** Re-export the handoff data if the prep script is newer than the `.parquet`/`.dta` it produced.
- **Treating EXPLAINED as a free pass.** Two consecutive cross-checks EXPLAINED by the same culprit without a fix is the two-strikes signal ([`summary-parity.md`](../../rules/summary-parity.md)) — surface it, don't re-record it.

## What this skill does NOT do

- **Audit the manuscript.** Paper-vs-outputs is [`/audit-reproducibility`](../audit-reproducibility/SKILL.md); this skill is outputs-vs-independent-re-run. Both run before submission.
- **Root-cause a divergence beyond the checklist.** That is [`/diagnose`](../diagnose/SKILL.md) (reproduce → minimise → bisect).
- **Replicate a published paper end-to-end.** That is `/data-analysis-stata` / `/data-analysis-r` plus `replication-protocol.md` Phase 1–4.
- **Decide which side is right.** Like the protocol says: the source result is a *challenger*, not an oracle — a divergence means "one of the two implementations must change; isolate which."

## Cross-references

- [`.claude/rules/replication-protocol.md`](../../rules/replication-protocol.md) — tolerance contract, handoff convention, language-pair pitfalls tables.
- [`.claude/skills/data-analysis-python/SKILL.md`](../data-analysis-python/SKILL.md) · [`.claude/skills/data-analysis-stata/SKILL.md`](../data-analysis-stata/SKILL.md) — the calling estimation pipelines.
- [`.claude/skills/audit-reproducibility/SKILL.md`](../audit-reproducibility/SKILL.md) — the manuscript-side verifier.
- [`.claude/skills/diagnose/SKILL.md`](../diagnose/SKILL.md) — divergence root-causing.
- [`.claude/skills/did-event-study/SKILL.md`](../did-event-study/SKILL.md) — owns the DiD dual-software cross-check; defer staggered-DiD estimands to it.
