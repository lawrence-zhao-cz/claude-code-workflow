* analysis_v3_FINAL.do
* Toy county program eval -- FINAL version (use this one, not v2!!)
* Lawrence, sometime 2024

clear all
set more off

* NOTE: update this path on the new laptop
use "C:\Users\lzhao\Dropbox\old_projects\county_program\panel_built.dta", clear

keep if year >= 2010 & year <= 2019

gen treat_post = treated * post

* main spec -- county + year FE, cluster county
areg y treat_post i.year, absorb(county) vce(cluster county)
outreg2 using "..\results\main_results.txt", replace

* robustness: drop the adoption year (partial exposure)
preserve
drop if year == 2015
areg y treat_post i.year, absorb(county) vce(cluster county)
outreg2 using "..\results\robust_no2015.txt", replace
restore

* old log-spec, R2 didn't like it
* areg ln_y treat_post i.year [aw=pop], absorb(county) vce(cluster county)
