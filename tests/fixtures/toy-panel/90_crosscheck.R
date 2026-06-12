# 90_crosscheck.R -- independent R re-implementation of S1/S2 from the PLAN ROWS
# (tests/fixtures/toy-plan/toy-panel-study.md), compared against the Stata
# primary per the tolerance contract (replication-protocol.md):
#   estimates rel <= 1e-2 | SEs rel <= 5e-2 | N exact.
# Verdicts: MATCH / DIVERGENT per spec-stat; exit 1 if any DIVERGENT.
# Inputs:  tests/fixtures/toy-panel/panel.csv, _outputs/stata_estimates.csv
# Run from the repo root: Rscript tests/fixtures/toy-panel/90_crosscheck.R [--seed-wrong-filter]
# Outputs: _outputs/r_estimates.csv, _outputs/crosscheck_report.txt

library(fixest)

args <- commandArgs(trailingOnly = TRUE)
seeded_wrong_filter <- length(args) > 0 && args[[1]] == "--seed-wrong-filter"

root <- "tests/fixtures/toy-panel"
panel <- read.csv(file.path(root, "panel.csv"))

stopifnot(nrow(panel) == 200L, !anyDuplicated(panel[, c("county", "year")]))

# S1 (plan row): TWFE y ~ d | county + year, cluster county, full panel
m_s1 <- feols(y ~ d | county + year, data = panel, cluster = ~county)

# S2 (plan row): same, excluding the 2015 transition year.
# The seeded variant plants the WRONG filter (2016) to test DIVERGENT detection.
drop_year <- if (seeded_wrong_filter) 2016L else 2015L
m_s2 <- feols(y ~ d | county + year,
              data = panel[panel$year != drop_year, ], cluster = ~county)

r_est <- data.frame(
  spec    = c("S1", "S2"),
  b       = c(unname(coef(m_s1)["d"]), unname(coef(m_s2)["d"])),
  se      = c(unname(se(m_s1)["d"]), unname(se(m_s2)["d"])),
  n       = c(m_s1$nobs, m_s2$nobs),
  n_clust = c(length(unique(panel$county)), length(unique(panel$county)))
)
write.csv(r_est, file.path(root, "_outputs", "r_estimates.csv"), row.names = FALSE)

stata <- read.csv(file.path(root, "_outputs", "stata_estimates.csv"))

tol_b <- 1e-2
tol_se <- 5e-2

lines <- c(sprintf("CROSS-CHECK REPORT  (seeded wrong filter: %s)", seeded_wrong_filter))
any_divergent <- FALSE
for (s in c("S1", "S2")) {
  st <- stata[stata$spec == s, ]
  rr <- r_est[r_est$spec == s, ]
  rel_b <- abs(rr$b - st$b) / abs(st$b)
  rel_se <- abs(rr$se - st$se) / abs(st$se)
  n_ok <- rr$n == st$n
  verdict_b <- if (rel_b <= tol_b) "MATCH" else "DIVERGENT"
  verdict_se <- if (rel_se <= tol_se) "MATCH" else "DIVERGENT"
  verdict_n <- if (n_ok) "MATCH" else "DIVERGENT"
  any_divergent <- any_divergent ||
    verdict_b == "DIVERGENT" || verdict_se == "DIVERGENT" || verdict_n == "DIVERGENT"
  lines <- c(lines, sprintf(
    "%s | b: stata %.6f vs R %.6f (rel %.2e) -> %s | se: %.6f vs %.6f (rel %.2e) -> %s | N: %d vs %d -> %s",
    s, st$b, rr$b, rel_b, verdict_b, st$se, rr$se, rel_se, verdict_se, st$n, rr$n, verdict_n
  ))
}
lines <- c(lines, sprintf("OVERALL: %s", if (any_divergent) "DIVERGENT" else "MATCH"))

writeLines(lines)
writeLines(lines, file.path(root, "_outputs", "crosscheck_report.txt"))
quit(status = if (any_divergent) 1L else 0L)
