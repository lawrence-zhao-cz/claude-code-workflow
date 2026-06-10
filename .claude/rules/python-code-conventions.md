---
paths:
  - "scripts/**/*.py"
  - "Figures/**/*.py"
  - "explorations/**/*.py"
---

# Python Code Conventions

**Standard:** Senior Principal Data Engineer + PhD researcher quality.

**Reproducibility is the default, not a feature.** A `.py` script should run from a clean environment with no manual intervention, and end in the same state regardless of how many times it runs.

> This rule mirrors [`r-code-conventions.md`](r-code-conventions.md) and [`stata-code-conventions.md`](stata-code-conventions.md) for **Python-first** pipelines — the default analysis language for data prep in this project (see the language-roles table in [`CLAUDE.md`](../../CLAUDE.md)). Scope: **analysis scripts** (data prep, estimation, simulation, figures). Python **package** source (`src/`, `pyproject.toml`, `tests/`) is out of scope here — that triad is on the backlog. The numerical discipline in §8 applies to both.

---

## 1. Environment & reproducibility scaffolding

- **uv** is the environment manager. Pin with `uv.lock`; export `requirements.txt` via `uv export` for journals/reviewers who expect it (see [`/capture-environment`](../skills/capture-environment/SKILL.md)).
- **Seed once, at the top, in `YYYYMMDD` form**, and use a **`Generator`**, never legacy global state:

  ```python
  import numpy as np
  SEED = 20260610
  rng = np.random.default_rng(SEED)   # pass `rng` explicitly; never np.random.seed()
  ```

  Legacy `np.random.seed()` / `random.seed()` mutate global state and are not thread-safe — pass `rng` into functions instead.
- **All imports at the top.** No imports inside functions or loops (except a documented optional-dependency guard).
- **All paths relative to repo root**, built with `pathlib.Path`. Never hardcode absolute paths or `C:\...` / `/Users/...`.
- **Create output dirs idempotently:** `OUT.mkdir(parents=True, exist_ok=True)`.

Every script starts with the same header:

```python
# ============================================================
# NN_descriptive_name.py
# Purpose:  [one-sentence description]
# Inputs:   [paths]
# Outputs:  [paths]
# Sequence: Standalone | After NN_prior.py
# ============================================================
```

(Use `Sequence:`, not `Run order:` — a leading "Run " trips downstream command guards.)

## 2. Numbered pipeline

Scripts live in `scripts/python/` and are numbered for run order, mirroring the R and Stata pipelines:

```
scripts/python/
├── 00_run_all.py        # orchestrates 01..05 in order; the one-command entry point
├── 01_load.py           # raw → in-memory / interim
├── 02_clean.py          # cleaning + the validation battery (§7)
├── 03_analyze.py        # estimation (statsmodels / linearmodels / pyfixest)
├── 04_tables.py         # publication tables → .tex
├── 05_figures.py        # figures → .pdf + .png
└── _outputs/            # all generated artifacts (data, tables, figures, env)
```

`python scripts/python/00_run_all.py` from the repo root reproduces every output the paper cites. This is the AEA one-command-reproduction shape ([`/replication-package`](../skills/replication-package/SKILL.md)).

## 3. Outputs & data persistence

All generated artifacts land in `scripts/python/_outputs/`:

- **Cleaned/interim data:** `.parquet` (columnar, typed, fast) for the Python-internal chain; **also write `.dta` via `pyreadstat`** when the data hands off to Stata, or `.feather`/`.parquet` for R (`arrow`). The cross-language handoff convention is the Phase 3 `/cross-check` contract.
- **Estimation objects:** pickle the fitted results (`joblib.dump`) so tables/figures load pre-computed objects instead of re-fitting — the Python analogue of R's `saveRDS()` pattern.
- **Tables:** `.tex` for direct `\input{}` in the manuscript (see §5).
- **Environment:** `uv export` + `uv.lock` captured for the replication package.

## 4. Estimation stack (applied micro)

- **Panel / high-dim FE / IV:** `pyfixest` (`feols`, reghdfe-equivalent; supports IV, Sun-Abraham/Did2s event study, wild bootstrap, Romano-Wolf) or `linearmodels` (`PanelOLS`, `IV2SLS`, GMM).
- **General models:** `statsmodels`.
- **ML-adjacent causal:** `econml` / `doubleml`.
- **Clustered SEs are the default** — cluster at the level of treatment assignment (or the highest plausible dependence level) and **document why**. Never ship default heteroskedastic-only SEs without justification.
- **Reproduce, don't guess.** If the user specifies a spec, run exactly that.

## 5. Tables

Never hand-format a results table in LaTeX — emit it from the actual estimation so values update mechanically:

```python
from pyfixest.estimation import feols
m1 = feols("y ~ x1 + x2 | unit + year", data=df, vcov={"CRV1": "unit"})
m1.etable(type="tex").to_file(OUT / "tab_main.tex")   # pyfixest native
# or statsmodels: summary_col(...).as_latex(); or `stargazer`, `pystout`
```

Then `\input{scripts/python/_outputs/tab_main.tex}` in the manuscript. Significance convention: `* 0.10 ** 0.05 *** 0.01` (econ default); state it in the table note.

## 6. Figures

Match the R/Stata figure conventions so Python figures drop into Beamer/Quarto unchanged:

```python
import matplotlib.pyplot as plt
fig, ax = plt.subplots(figsize=(12, 5))
# ... plot ...
fig.savefig(OUT / "fig_event.pdf", transparent=True, bbox_inches="tight")
fig.savefig(OUT / "fig_event.png", dpi=200, transparent=True, bbox_inches="tight")
```

- **Transparent background** (`transparent=True`) — avoids white boxes on slides.
- **Explicit `figsize`**; both vector (`.pdf` for the paper) and raster (`.png` for slides).
- **Use the project palette** — the same colors as `Preambles/header.tex` / `Quarto/theme-template.scss` (the palette-sync contract), not matplotlib defaults.
- Axis labels: sentence case, units included; legend readable at projection size.
- For curved annotations / `arc3` arrows, compute label positions per [`tikz-measurement.md`](tikz-measurement.md) (it has copy-paste matplotlib `arc3` helpers).

## 7. Data-prep validation battery (mandatory in `02_clean.py`)

Every cleaning script ends with explicit assertions on the cleaned frame — this is half of the "verify the prep is accurate" requirement (the other half, independent cross-language re-implementation, is Phase 3 `/cross-check`):

```python
assert df["id"].is_unique, "id is not a primary key"                 # key uniqueness
assert df.shape[0] == EXPECTED_N, f"row count {df.shape[0]} != {EXPECTED_N}"
m = pd.merge(a, b, on="id", how="outer", indicator=True)             # merge match rate
assert (m["_merge"] == "both").mean() > 0.99, "merge match rate < 99%"
assert df["share"].between(0, 1).all(), "share outside [0,1]"        # value ranges
print(df.isna().mean().sort_values(ascending=False).head())          # missingness snapshot
```

Fail loud at clean time, never silently downstream. Mirrors Stata's `merge ..., assert(3)` discipline.

## 8. Numerical discipline

Headline rules (mirror `r-code-conventions.md` §8 / `r-reviewer` Category 11):

- **No float equality.** Never `==` on floats. Use `np.isclose(a, b)` / `math.isclose`.
- **CDF clamping to an OPEN interval.** Exact 0 or 1 into `scipy.stats.norm.ppf` etc. gives `±inf`. Clamp: `eps = 1e-12; p = np.clip(p, eps, 1 - eps)`.
- **Explicit integer dtypes for counts** (`np.int64`); don't let counts become floats via silent NaN promotion.
- **Vectorize; pre-allocate.** Don't grow lists in a loop then `np.array()` in hot paths — pre-allocate `np.empty(n)`. Avoid `DataFrame.append`/`pd.concat` inside loops.
- **Deterministic bootstrap.** Spawn child generators: `child_rngs = rng.spawn(B)` (or `seed + b`), never reseed inside the loop.
- **Explicit NA handling.** State `skipna=` / `dropna()` intent; never rely on pandas defaults for `mean`/`sum`/`std` on data with NAs.
- **Avoid chained assignment** (`df[df.x>0]["y"] = ...`) — use `.loc`; respect copy-vs-view.

## 9. Style & tooling

- **`ruff`** for lint + format (or `black` + `ruff`); **`mypy`** optional but encouraged on library-like code.
- `snake_case` functions, verb-noun (`load_panel`, `estimate_att`); type hints on non-trivial signatures; docstrings (NumPy or Google style).
- Lines ≤ 100 chars — **exception** for math-dense lines that match a paper equation (same carve-out as `r-code-conventions.md` §7), with an inline comment explaining the operation.
- Comments explain **WHY**, not WHAT. No commented-out dead code.

## 10. Code quality checklist

```
[ ] uv env; uv.lock committed
[ ] SEED once at top (YYYYMMDD) via np.random.default_rng; rng passed explicitly
[ ] All imports at top; all paths relative via pathlib
[ ] Numbered pipeline; 00_run_all.py reproduces everything
[ ] Cleaned data persisted (.parquet; .dta/.feather for handoff)
[ ] Estimation objects pickled for table/figure scripts
[ ] Clustered SEs with documented level
[ ] Tables emitted to .tex (no hand-formatting)
[ ] Figures: transparent bg, explicit figsize, project palette, .pdf + .png
[ ] 02_clean.py ends with the validation battery (§7)
[ ] Numerical discipline: no float ==, CDF clamping, explicit NA, deterministic RNG
[ ] ruff clean
```

## Enforcement & cross-references

- [`/python-analysis`](../skills/python-analysis/SKILL.md) — emits pipelines conforming to this rule (analogue of `/data-analysis` for R, `/stata-replication` for Stata).
- [`/review-python`](../skills/review-python/SKILL.md) + the `python-reviewer` agent — read-only review against this rule.
- [`/audit-reproducibility`](../skills/audit-reproducibility/SKILL.md) — reads `.parquet`/`.dta` outputs; cross-checks manuscript numbers.
- [`replication-protocol.md`](replication-protocol.md) — cross-language tolerance contract (R / Stata / Python).
- [`r-code-conventions.md`](r-code-conventions.md) · [`stata-code-conventions.md`](stata-code-conventions.md) — sibling disciplines.
