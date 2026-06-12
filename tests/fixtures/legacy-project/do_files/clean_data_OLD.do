* clean_data_OLD.do -- builds panel_built.dta from the raw extract
clear all
import excel "K:\shared\county_program\panel_raw.xlsx", firstrow

drop if missing(y)
drop if year < 2010
gen treated = county >= 11
gen post = year >= 2015

* merge in population, match should be perfect but who knows
merge 1:1 county year using "K:\shared\county_program\pop.dta"
drop if _merge == 2
drop _merge

save "C:\Users\lzhao\Dropbox\old_projects\county_program\panel_built.dta", replace
