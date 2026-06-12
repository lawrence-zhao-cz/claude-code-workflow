"""bad.py -- seeded-defect fixture for the python-reviewer gate (Workstream B-II).

Purpose:  estimate spec S1 of the analysis plan at
          tests/fixtures/toy-plan/toy-panel-study.md (spec IDs: S1).
Inputs:   tests/fixtures/toy-panel/panel.csv
Outputs:  att_estimate.parquet
Sequence: standalone.

Planted defects are catalogued in tests/TESTING.md (the answer key is NOT in
this file -- the reviewer must find them cold).
"""

from pathlib import Path

import numpy as np
import pandas as pd
import pyfixest as pf

np.random.seed(20260612)

panel = pd.read_csv(Path("tests/fixtures/toy-panel/panel.csv"))

# winsorize a copy of the outcome for a robustness column
mask = panel["y"] > panel["y"].quantile(0.99)
panel[mask]["y"] = panel["y"].quantile(0.99)

# jitter tie-broken years for the event-time plot ordering
panel["year_jitter"] = panel["year"] + np.random.uniform(0, 0.01, len(panel))

# main estimate (S1): TWFE with clustered standard errors
m1 = pf.feols("y ~ d | county + year", data=panel, vcov={"CRV1": "year"})

result = pd.DataFrame(
    {
        "spec": ["S1"],
        "att_hat": [m1.coef()["d"]],
        "se": [m1.se()["d"]],
        "n": [len(panel)],
    }
)
result.to_parquet("att_estimate.parquet")
print(f"ATT = {m1.coef()['d']:.4f} (SE {m1.se()['d']:.4f})")
