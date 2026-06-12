* analysis_v2.do  -- SUPERSEDED by analysis_v3_FINAL.do, keeping just in case
clear all
use "C:\Users\lzhao\Dropbox\old_projects\county_program\panel_built.dta", clear
gen treat_post = treated * post
xtset county year
xtreg y treat_post i.year, fe robust
* TODO: switch to clustered SEs like the referee asked
