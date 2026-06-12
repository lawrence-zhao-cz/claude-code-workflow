/*------------------------------------------------------------
File:       run_estimates.do
Purpose:    Estimate S1 + S2 (toy-panel-study plan rows) as the Stata
            primary for the /cross-check T4 test rows.
Inputs:     tests/fixtures/toy-panel/panel.dta
Outputs:    tests/fixtures/toy-panel/_outputs/stata_estimates.csv
Sequence:   Standalone (run from the repo root; see tests/TESTING.md)
------------------------------------------------------------*/
version 17
clear all
set more off
set seed 12345
set sortseed 12345

* stata-mcp executes do-files outside the repo cwd; set the global first
* (e.g. a local runner: global WORKFLOW_ROOT "C:/path/to/clone" + do this file)
if `"${WORKFLOW_ROOT}"' != "" cd "${WORKFLOW_ROOT}"

* reghdfe per plan row Estimator (install handled outside this script —
* the stata-mcp guard correctly blocks in-script package management)
which reghdfe

use "tests/fixtures/toy-panel/panel.dta", clear

* validation battery: known invariants of the fixture
isid county year
assert _N == 200
assert inlist(d, 0, 1)

tempname results
postfile `results' str4 spec double(b se) long(n n_clust) ///
    using "tests/fixtures/toy-panel/_outputs/stata_estimates_tmp", replace

* S1 (plan row): TWFE y on d, FE county+year, cluster county, full panel
reghdfe y d, absorb(county year) vce(cluster county)
post `results' ("S1") (_b[d]) (_se[d]) (e(N)) (e(N_clust))

* S2 (plan row): same, excluding the 2015 transition year
preserve
drop if year == 2015
reghdfe y d, absorb(county year) vce(cluster county)
post `results' ("S2") (_b[d]) (_se[d]) (e(N)) (e(N_clust))
restore

postclose `results'
use "tests/fixtures/toy-panel/_outputs/stata_estimates_tmp.dta", clear
export delimited using "tests/fixtures/toy-panel/_outputs/stata_estimates.csv", replace
list, clean

exit, clear STATA
