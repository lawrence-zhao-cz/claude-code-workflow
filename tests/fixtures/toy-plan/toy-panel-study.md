# Analysis Plan — toy-panel-study

**Status:** APPROVED (fixture)
**Date:** 2026-06-12
**Interview log:** `toy-panel-study_interview_log.md` (verbatim source of intent)
**Data:** `tests/fixtures/toy-panel/panel.csv` / `panel.dta` (synthetic, known DGP)

> Fixture note: this is the FAITHFUL variant — every row below is grounded in
> the interview log. The seeded-divergence variant for plan-auditor testing is
> `toy-panel-study_divergent.md`.

## 1. Data & cleaning filters

- Source: toy panel, 20 counties × years 2010–2019, balanced (N = 200).
- Treatment: counties 11–20, treated from 2015 onward (common timing).
- No observations dropped; no imputation; no weights.

## 2. Specifications

| ID | Status | Outcome | Regressors | FE | Cluster | Sample | Weights | Estimator | Lang | Feeds | Notes |
|----|--------|---------|------------|----|---------|--------|---------|-----------|------|-------|-------|
| S1 | PLANNED | y | d (treated×post) | county, year | county | full panel 2010–2019 | none | TWFE (`reghdfe`) | Stata | toy-paper Table 1 | 20 clusters — few-cluster caveat noted per user; plain CRVE accepted for the toy run |
| S2 | PLANNED | y | d (treated×post) | county, year | county | excl. year 2015 | none | TWFE (`reghdfe`) | Stata | toy-paper robustness ¶ | partial-exposure adoption year dropped |

## 3. Figures & tables

- Table 1: S1 point estimate + cluster SE + N.
- Robustness paragraph: S2 estimate + N.

## 4. Cross-check

- R re-implementation (`fixest::feols`) of S1 and S2 from the plan rows above;
  tolerance per the replication protocol.

## 5. Ad-hoc appendix / archive

*(empty — no ad-hoc runs yet)*
