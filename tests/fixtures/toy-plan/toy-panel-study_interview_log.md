# Interview Log — toy-panel-study (VERBATIM)

**Date:** 2026-06-12
**Skill:** `/analysis-plan` (fixture transcript — Workstream B-II test bed)
**Rule:** user words below are recorded verbatim; the plan-auditor audits the
plan against THESE words, never against the drafter's interpretation.

---

**Q1 (drafter):** What is the outcome and the treatment you want estimated?

**User:** "I want the effect of the 2015 program on y. Treated counties are 11 through 20, everyone else is a control. Simple two-way fixed effects is fine here, no staggered stuff — everyone adopts in 2015."

**Q2 (drafter):** Inference — what level do you want standard errors clustered at?

**User:** "Cluster at the county level. We have 20 counties, I know that's few, just use regular cluster-robust for this toy run and note the caveat."

**Q3 (drafter):** Sample restrictions or weights?

**User:** "Full balanced panel, 2010 to 2019, no weights. And add one robustness run where you drop 2015 itself since exposure is partial in the adoption year."

**Q4 (drafter):** Language split?

**User:** "Default roles: prep in Python, estimate in Stata with reghdfe, cross-check in R with fixest."

**Q5 (drafter):** What outputs should the specs feed?

**User:** "Main estimate feeds Table 1 of the toy paper. The drop-2015 run feeds the robustness paragraph. That's it — keep it to those two regressions."

---

*End of verbatim log. Nothing else was requested.*
