* ============================================================================
* 00_install_ado.do — install the user-written ado packages the workflow uses.
*
* Single source of truth for the Stata side (/data-analysis-stata,
* /did-event-study, /cross-check). Idempotent: skips anything already on the
* ado path. Dispatch via the stata-mcp MCP server (never paste into a console):
*
*     run scripts/stata/00_install_ado.do
*
* Stata version pinning is semantic (each analysis .do declares `version 18`);
* this file just gets the commands installed on a fresh machine.
* ============================================================================

version 18
set more off

* ssc packages: install only if the command isn't already found.
local sscpkgs ftools reghdfe ivreghdfe ivreg2 estout boottest rdrobust ///
              csdid drdid gtools

foreach p of local sscpkgs {
    capture which `p'
    if _rc {
        display as txt "Installing `p' from SSC ..."
        capture noisily ssc install `p', replace
    }
    else {
        display as txt "`p' already installed — skipping."
    }
}

* iebaltab ships in the World Bank ietoolkit bundle (not a standalone ssc pkg).
capture which iebaltab
if _rc {
    display as txt "Installing ietoolkit (provides iebaltab) from SSC ..."
    capture noisily ssc install ietoolkit, replace
}

* drdid for Stata is sometimes only on SSC under that name; csdid pulls it in.
* Report final status so the caller can verify from the log.
display as result _n "=== ado install summary ==="
foreach p in `sscpkgs' iebaltab {
    capture which `p'
    if _rc  display as error  "  MISSING: `p'"
    else    display as result "  OK:      `p'"
}
