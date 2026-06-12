# tests/ — The Workflow Test Bed

**Created:** Workstream B-II (2026-06-12), per the approved plan (`quality_reports/plans/swift-hugging-fog.md`).
**Purpose:** a reviewer that has never caught a planted bug is untested. This directory holds deterministic fixtures with **known ground truth** so every gate in the workflow can be exercised — and *fail-tested* — repeatably.

**Gate plumbing:** `.githooks/pre-commit` exempts `tests/fixtures/**` from the quality score (these files are deliberately defective). Everything else in the repo is scored as usual, now including `.py`/`.do`.

---

## 1. Fixture inventory

| Fixture | Contents | Exercises |
|---|---|---|
| `fixtures/toy-panel/` | `make_fixtures.py` (seeded generator), `panel.csv`, `panel.dta`, `expected_estimates.json` | `/data-analysis-{python,stata,r}`, `/cross-check`, `/audit-reproducibility` |
| `fixtures/toy-lecture/` | 5-frame self-contained Beamer deck + bib + Quarto mirror (equation, citation, box env, TikZ timeline) | `/compile-latex`, `/translate-to-quarto`, `/qa-quarto`, `/extract-tikz` |
| `fixtures/toy-paper/` | `.tex` manuscript + bib with planted numeric claims and one fabricated citation | `/audit-reproducibility`, `/verify-claims`, `/review-paper`, `claim-verifier` |
| `fixtures/toy-plan/` | analysis plan + VERBATIM interview log + seeded-divergence plan variant | `plan-auditor` (plan mode), `/analysis-plan` import |
| `fixtures/legacy-project/` | deliberately messy pre-workflow Stata project (versioned do-files, hardcoded paths, K:-drive data pointers, stray notes, old-style CLAUDE.md) | `/onboard-project` (dossier extraction, migration map, `--dry-run`) |
| `fixtures/seeded-defects/` | `bad.R`, `bad.py`, `bad.do`, `bad_slide.tex` — each with catalogued planted defects | `r-reviewer`, `python-reviewer`, `stata-reviewer`, `proofreader`, `slide-auditor` |

### Ground truth (toy-panel)

DGP: `y_it = county FE + year FE + ATT·D_it + N(0,1)`, 20 counties × 2010–2019 (N=200, balanced), counties 11–20 treated from 2015 (common timing). **TRUE_ATT = 2.0.** Seed `20260612`.

Seeded reference estimates (`expected_estimates.json`, numpy TWFE + CR1 county-clustered SE):

| Spec | ATT̂ | SE | N | Clusters |
|---|---|---|---|---|
| Main (S1) | 1.7124 | 0.3681 | 200 | 20 |
| Excl. 2015 (S2) | 1.6236 | 0.3747 | 180 | 20 |

Stata/R re-estimates may differ in small-sample dof conventions — the tolerance contract (`replication-protocol.md`: estimates rel. 1e-2, SEs rel. 5e-2, N exact) is the standard, not digit equality. **Regenerate:** `uv run python tests/fixtures/toy-panel/make_fixtures.py` (fully deterministic; the numbers above and every planted claim keyed to them only change if the seed or DGP changes — if you change either, update this file AND `toy-paper.tex`/`toy-lecture` in the same commit).

---

## 2. Answer key — planted defects

> The fixtures themselves never label their defects; reviewers must find them cold. This section is the only catalogue.

### toy-paper (`fixtures/toy-paper/toy-paper.tex`)

| # | Claim (location) | Type | Expected gate verdict |
|---|---|---|---|
| P1 | §3.1: ATT̂ = 1.71, SE 0.37 | matches `main` | `/audit-reproducibility` **PASS** |
| P2 | §2: N = 200, 20 counties/clusters | matches `main` | **PASS** |
| P3 | Abstract: "treatment effect of 1.94 units" | off-tolerance vs 1.71 (also contradicts §3.1) | **FAIL** (and internal-consistency flag in `/review-paper`) |
| P4 | §3.2: excl.-2015 effect 1.62, N = 180 | named defensible alternative (`alt_excl_2015`) | **EXPLAINED** with the note; not FAIL |
| P5 | `smith2019placebo` (bib + 2 citations) | fabricated reference — *Quarterly Journal of Placebo Studies* does not exist | `claim-verifier` / `/verify-claims` **HIGH-WARN / cannot-verify** |

### toy-plan divergent variant (`fixtures/toy-plan/toy-panel-study_divergent.md`, vs the SAME interview log)

| # | Element | Plant | Expected `plan-auditor` verdict |
|---|---|---|---|
| L1 | S1 `Cluster` = state | log says verbatim "Cluster at the county level" | **DIVERGES** |
| L2 | S3 (log-y, population weights) | log says "keep it to those two regressions"; S3 never requested | **UNSUPPORTED-ADDITION** |
| — | S2 row | faithful | MATCHES |

The faithful variant (`toy-panel-study.md`) must come back **PASS** (no DIVERGES/OMISSION) — a gate that flags everything is as useless as one that flags nothing.

### bad.R (`r-reviewer`)

| # | Defect | Location |
|---|---|---|
| R1 | `require()` instead of `library()` (×2) | top of script |
| R2 | grown vector: `cell_means <- c()` + `c(cell_means, m)` in loop | balance-check loop |
| R3 | float equality `== 1.0` (×2: the `mean(...)` check and `noise_sd == 1.0`) | sanity checks |

### bad.py (`python-reviewer`)

| # | Defect | Location |
|---|---|---|
| Y1 | `np.random.seed()` global seeding (house rule: `default_rng`) | setup |
| Y2 | chained assignment `panel[mask]["y"] = ...` — a silent no-op; the winsorization never happens | winsorize block |
| Y3 | **plan-fidelity:** `vcov={"CRV1": "year"}` but plan row S1 says cluster = **county** | estimation call — the script's own header cites the plan, so a header-only review misses this; the reviewer must check the plan row |

### bad.do (`stata-reviewer`)

| # | Defect | Location |
|---|---|---|
| D1 | bare `capture merge` + `capture drop _merge` — merge errors swallowed silently; no `assert`/match-rate check | merge block |
| D2 | no `version`, no `set seed` before `bsample` — nondeterministic | preamble / bootstrap line |
| D3 | `bsample` **destructively resamples before the main estimation** — S1 is estimated on a bootstrap draw, not the data | order of operations (the quiet killer) |

### bad_slide.tex (`proofreader` + `slide-auditor`)

| # | Defect | Type |
|---|---|---|
| T1 | "Programe", "recieve", "teh", "in in", "which which", "the the", "Effect sizes is" | typos / doubled words / agreement (proofreader) |
| T2 | 11-column `\tiny` table + overlong frame title + `\vspace{-3em}` + prose-stuffed equation | overflow / readability (slide-auditor; the spacing-first principle should reject the `\vspace` hack and demand a split) |

### legacy-project (`/onboard-project`)

Not defects — **extraction targets** the dossier must capture with `file:line` provenance: spec (y on treat_post, county+year FE, county cluster, 2010–2019) from `analysis_v3_FINAL.do`; the drop-2015 robustness; the v3-not-v2 supersession; the K:-drive data location + DUA note (data must NOT be pulled into git); decisions in `notes/meeting_notes_2024-03.txt` (county clustering kept, log spec dropped). Hard-rule checks: nothing moved/deleted without an approved migration map; legacy code never auto-run.

---

## 3. Tier map (T1–T4) and how to re-run

| Tier | What | How |
|---|---|---|
| **T1** mechanical | surface-sync, skill-integrity, model-versions, hook syntax | `./scripts/check-surface-sync.sh`; `bash -n .githooks/pre-commit` — deterministic, run any time |
| **T2** per-skill smoke | each chain component on its fixture (see inventory table) | invoke the skill on the fixture path; conversational skills (`/interview-me`, `/analysis-plan`) run as short live interviews |
| **T3** integration chains | research flagship (onboard → interview → plan → prep → estimate → cross-check → review → audit), lecture chain, paper chain (+ one `--peer` run) | per the Workstream B plan; onboarding targets a temp dir |
| **T4** seeded-defect matrix | every answer-key row above: defect → expected → actual → PASS/**MISS** | run the gate against the fixture; every MISS becomes an agent-prompt fix, then the row re-runs until all PASS. Record results in `quality_reports/testing/` (local) |

**A row passes only if the gate names the planted defect specifically** — a generic "could be improved" does not count as a catch.

**Status (2026-06-12):** first T4 run — all 8 autonomous gate rows (3 code reviewers, proofreader, slide-auditor, plan-auditor ×2, claim-verifier) **16/16 PASS incl. both negative controls; zero misses**. Deferred rows (cross-check, audit-reproducibility, verifier/compile, onboarding, live interviews) await the T2/T3 session + XeLaTeX/Quarto install. Full results: `quality_reports/testing/` (local).

### Environment prerequisites

| Tool | Needed by | Status on this box (2026-06-12) |
|---|---|---|
| uv + Python (numpy/pandas) | toy-panel generator, `/data-analysis-python` | ✅ installed |
| Stata (via `stata-mcp`) | `/data-analysis-stata`, bad.do runs | ✅ installed |
| R (fixest/did) | `/cross-check`, `/data-analysis-r` | ✅ installed |
| **XeLaTeX** | toy-lecture compile, toy-paper compile, T3 lecture chain | ❌ **not installed** — install MiKTeX or TeX Live before T2 lecture tests |
| **Quarto** | toy-lecture Quarto mirror render, `/qa-quarto` | ❌ **not installed** — install before T2 lecture tests |

The toy-lecture deck is written but **compile-unverified** until XeLaTeX is available (it is deliberately self-contained — `xelatex toy-lecture` from its directory, 3-pass + bibtex).

### Public-facing caution

Fixture content never deploys to `docs/` (no `sync_to_docs.sh` on fixtures). The T3 onboarding target is a temp directory, deleted after the run.
