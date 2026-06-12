"""Generate the toy-panel test fixture: a synthetic county-by-year panel with a KNOWN ATT.

Purpose:  deterministic test bed for /data-analysis-*, /cross-check, and
          /audit-reproducibility (Workstream B-II; see tests/TESTING.md).
Inputs:   none (pure simulation).
Outputs:  panel.csv, panel.dta, expected_estimates.json (all in this directory).
Sequence: standalone — run `uv run python tests/fixtures/toy-panel/make_fixtures.py`.

DGP: y_it = alpha_i + gamma_t + TRUE_ATT * D_it + eps_it,  eps ~ N(0, 1)
     20 counties (ids 1-20), years 2010-2019 (N = 200, balanced).
     Counties 11-20 treated from 2015 onward (common timing, homogeneous effect),
     so TWFE recovers the ATT without staggered-adoption contamination.
     TRUE_ATT = 2.0 — the number every downstream estimate is judged against.

The reference estimates below are computed with plain numpy OLS (county + year
dummies) and CR1 county-clustered SEs. Stata/R re-estimates in B-III may differ
in small-sample dof conventions; the tolerance contract (estimates rel. 1e-2,
SEs rel. 5e-2) is what matters, not digit-for-digit equality.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

# --- 0. Setup -----------------------------------------------------------
SEED = 20260612
TRUE_ATT = 2.0
N_COUNTIES = 20
YEARS = np.arange(2010, 2020)
TREAT_START = 2015
TREATED_IDS = np.arange(11, 21)

OUT_DIR = Path(__file__).resolve().parent
rng = np.random.default_rng(SEED)

# --- 1. Simulate the panel ----------------------------------------------
county = np.repeat(np.arange(1, N_COUNTIES + 1), len(YEARS))
year = np.tile(YEARS, N_COUNTIES)
treated = np.isin(county, TREATED_IDS).astype(int)
post = (year >= TREAT_START).astype(int)
d = treated * post

alpha = rng.normal(0.0, 2.0, size=N_COUNTIES)  # county effects
gamma = rng.normal(0.0, 1.0, size=len(YEARS))  # year effects
eps = rng.normal(0.0, 1.0, size=len(county))

y = alpha[county - 1] + gamma[year - YEARS[0]] + TRUE_ATT * d + eps

panel = pd.DataFrame(
    {
        "county": county.astype(np.int64),
        "year": year.astype(np.int64),
        "treated": treated.astype(np.int64),
        "post": post.astype(np.int64),
        "d": d.astype(np.int64),
        "y": y,
    }
)


# --- 2. Reference TWFE estimate + CR1 county-clustered SE ----------------
def twfe_att(df: pd.DataFrame) -> dict[str, float]:
    """OLS of y on D + county and year dummies; CR1 SE clustered by county."""
    c_dum = pd.get_dummies(df["county"], prefix="c", drop_first=True, dtype=float)
    t_dum = pd.get_dummies(df["year"], prefix="t", drop_first=True, dtype=float)
    x = np.column_stack(
        [df["d"].to_numpy(float), np.ones(len(df)), c_dum.to_numpy(), t_dum.to_numpy()]
    )
    yv = df["y"].to_numpy(float)

    beta, *_ = np.linalg.lstsq(x, yv, rcond=None)
    resid = yv - x @ beta

    bread = np.linalg.inv(x.T @ x)
    clusters = df["county"].to_numpy()
    meat = np.zeros((x.shape[1], x.shape[1]))
    for g in np.unique(clusters):
        xg = x[clusters == g]
        sg = xg.T @ resid[clusters == g]
        meat += np.outer(sg, sg)
    n_obs, k = x.shape
    n_g = len(np.unique(clusters))
    cr1 = (n_g / (n_g - 1)) * ((n_obs - 1) / (n_obs - k))
    vcov = cr1 * bread @ meat @ bread

    return {
        "att_hat": float(beta[0]),
        "se_cluster_county": float(np.sqrt(vcov[0, 0])),
        "n": int(n_obs),
        "n_clusters": int(n_g),
    }


main_spec = twfe_att(panel)
alt_spec = twfe_att(panel[panel["year"] != TREAT_START])  # named alternative:
# excluding the transition year 2015 — the "defensible alternative" the
# toy-paper cites for the EXPLAINED test case in /audit-reproducibility.

# --- 3. Persist ----------------------------------------------------------
panel.to_csv(OUT_DIR / "panel.csv", index=False)
panel.to_stata(OUT_DIR / "panel.dta", write_index=False, version=118)

estimates = {
    "seed": SEED,
    "dgp": "y = county FE + year FE + ATT*D + N(0,1); common timing 2015",
    "true_att": TRUE_ATT,
    "main": main_spec,
    "alt_excl_2015": {
        "note": "same TWFE spec, sample excludes the 2015 transition year",
        **alt_spec,
    },
}
(OUT_DIR / "expected_estimates.json").write_text(
    json.dumps(estimates, indent=2) + "\n", encoding="utf-8"
)

print(
    f"toy-panel written: N={main_spec['n']}, true ATT={TRUE_ATT}, "
    f"ATT_hat={main_spec['att_hat']:.4f} (SE {main_spec['se_cluster_county']:.4f}), "
    f"alt (excl. 2015) ATT_hat={alt_spec['att_hat']:.4f}"
)
