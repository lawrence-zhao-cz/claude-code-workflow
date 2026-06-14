# =============================================================================
# install-packages.R — install the R packages the workflow's skills rely on.
#
# Single source of truth for the R side (/data-analysis-r, /cross-check,
# /did-event-study, /simulation-study, /power-analysis, /r-package-check).
# Idempotent: only installs packages not already present.
#
#   Rscript scripts/R/install-packages.R
#
# Exact-version pinning for a replication package is /capture-environment's
# job (renv.lock); this script just gets a working analysis toolchain onto a
# fresh machine.
# =============================================================================

# A non-interactive CRAN mirror so this runs headless on a new machine.
options(repos = c(CRAN = "https://cloud.r-project.org"))

pkgs <- c(
  # data manipulation + viz
  "tidyverse",     # dplyr, tidyr, ggplot2, readr, purrr, ...
  "here",          # project-relative paths
  "conflicted",    # explicit namespace conflict resolution

  # typed cross-language handoff
  "haven",         # read/write .dta (Stata <-> R)
  "arrow",         # read/write parquet (Python <-> R)

  # estimation (applied micro)
  "fixest",        # feols: panel / high-dim FE / IV
  "modelsummary",  # regression + summary tables -> .tex
  "stargazer",     # alternative table output

  # staggered DiD / event study
  "did",           # Callaway & Sant'Anna att_gt
  "DRDID",         # doubly-robust 2x2
  "HonestDiD",     # sensitivity analysis
  "staggered",     # efficient staggered estimator

  # simulation + power
  "furrr",         # parallel map for Monte Carlo
  "pwr",           # power analysis
  "WebPower",      # clustered / complex-design power
  "AER"            # applied econometrics datasets + ivreg
)

# didFF and contdid are GitHub-only / fast-moving; install if missing, but
# never fail the whole script on them. VERIFY these source paths against the
# package docs before relying on them — a stale path just logs "Skipped".
github_pkgs <- c(
  "contdid" = "bcallaway11/contdid"
)

installed <- rownames(installed.packages())
to_install <- setdiff(pkgs, installed)

if (length(to_install) == 0L) {
  message("All CRAN workflow packages already installed.")
} else {
  message("Installing: ", paste(to_install, collapse = ", "))
  install.packages(to_install, dependencies = TRUE)
}

# Optional GitHub-only packages (best-effort; never error the run).
if (!requireNamespace("remotes", quietly = TRUE)) {
  try(install.packages("remotes"), silent = TRUE)
}
if (requireNamespace("remotes", quietly = TRUE)) {
  for (nm in names(github_pkgs)) {
    if (!nm %in% rownames(installed.packages())) {
      tryCatch(
        remotes::install_github(github_pkgs[[nm]], upgrade = "never"),
        error = function(e) message("Skipped ", nm, " (GitHub install failed): ", conditionMessage(e))
      )
    }
  }
} else {
  message("remotes unavailable — skipping GitHub-only packages: ",
          paste(names(github_pkgs), collapse = ", "))
}

# Report what is now available so the caller can verify.
final <- rownames(installed.packages())
want  <- c(pkgs, names(github_pkgs))
missing <- setdiff(want, final)
if (length(missing)) {
  message("STILL MISSING (install manually): ", paste(missing, collapse = ", "))
} else {
  message("R workflow toolchain complete.")
}
