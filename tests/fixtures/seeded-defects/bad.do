* bad.do -- seeded-defect fixture for the stata-reviewer gate (Workstream B-II).
* Estimates spec S1 of tests/fixtures/toy-plan/toy-panel-study.md.
* Planted defects are catalogued in tests/TESTING.md (answer key NOT here).
*
* Inputs:  tests/fixtures/toy-panel/panel.dta
* Outputs: _outputs/att_s1.ster

clear all
set more off

use "tests/fixtures/toy-panel/panel.dta", clear

* bring in a county-area lookup for the per-capita robustness column
capture merge 1:1 county year using "tests/fixtures/toy-panel/county_area.dta"
drop if _merge == 2
capture drop _merge

* bootstrap the few-cluster p-value for the writeup
bsample, cluster(county)

* main estimate (S1): TWFE, county clustering
reghdfe y d, absorb(county year) vce(cluster county)
estimates save "_outputs/att_s1", replace

display "ATT = " _b[d]
