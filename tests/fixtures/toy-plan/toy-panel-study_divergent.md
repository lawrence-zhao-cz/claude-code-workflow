# Analysis Plan — toy-panel-study

**Status:** APPROVED (fixture — SEEDED-DIVERGENCE VARIANT)
**Date:** 2026-06-12
**Interview log:** `toy-panel-study_interview_log.md` (verbatim source of intent)
**Data:** `tests/fixtures/toy-panel/panel.csv` / `panel.dta` (synthetic, known DGP)

> Fixture note: this variant plants two intent errors against the SAME
> interview log; the answer key is in `tests/TESTING.md`. Auditing this file
> against the log must NOT return PASS.

## 1. Data & cleaning filters

- Source: toy panel, 20 counties × years 2010–2019, balanced (N = 200).
- Treatment: counties 11–20, treated from 2015 onward (common timing).
- No observations dropped; no imputation.

## 2. Specifications

| ID | Status | Outcome | Regressors | FE | Cluster | Sample | Weights | Estimator | Lang | Feeds | Notes |
|----|--------|---------|------------|----|---------|--------|---------|-----------|------|-------|-------|
| S1 | PLANNED | y | d (treated×post) | county, year | state | full panel 2010–2019 | none | TWFE (`reghdfe`) | Stata | toy-paper Table 1 | clustered at the state level for conservatism |
| S2 | PLANNED | y | d (treated×post) | county, year | county | excl. year 2015 | none | TWFE (`reghdfe`) | Stata | toy-paper robustness ¶ | partial-exposure adoption year dropped |
| S3 | PLANNED | log(y) | d (treated×post) | county, year | county | full panel 2010–2019 | population | TWFE (`reghdfe`) | Stata | appendix elasticity table | log specification for percent effects |

## 3. Figures & tables

- Table 1: S1 point estimate + cluster SE + N.
- Robustness paragraph: S2 estimate + N.
- Appendix: S3 elasticity table.

## 4. Cross-check

- R re-implementation (`fixest::feols`) of all specs from the plan rows above.

## 5. Ad-hoc appendix / archive

*(empty)*
