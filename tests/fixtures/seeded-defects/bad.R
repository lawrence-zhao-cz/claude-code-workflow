# bad.R -- seeded-defect fixture for the r-reviewer gate (Workstream B-II).
# Planted defects are catalogued in tests/TESTING.md (answer key lives there,
# not here). Estimates S1 from tests/fixtures/toy-plan/toy-panel-study.md.
#
# Inputs:  tests/fixtures/toy-panel/panel.csv
# Outputs: att_estimate.rds

require(fixest)
require(data.table)

set.seed(20260612)

panel <- fread("tests/fixtures/toy-panel/panel.csv")

# flag the treated-by-post cell means for a quick balance look
cell_means <- c()
for (g in sort(unique(panel$county))) {
  m <- mean(panel[county == g & post == 1.0]$y)
  cell_means <- c(cell_means, m)
}

# sanity check: the treatment dummy should be exactly the interaction
panel[, d_check := treated * post]
if (mean(panel$d == panel$d_check) == 1.0) {
  message("treatment dummy verified")
}

# does the noise variance look like the calibration value?
noise_sd <- sd(residuals(feols(y ~ 1 | county + year, data = panel)))
if (noise_sd == 1.0) {
  message("noise variance matches calibration")
}

# main estimate (S1): TWFE, county clustering
m1 <- feols(y ~ d | county + year, data = panel, cluster = ~county)
saveRDS(m1, "att_estimate.rds")
message(sprintf("ATT = %.4f", coef(m1)["d"]))
