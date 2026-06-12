# Agent Fleet Manifest

The 20 specialist subagents, what each is for, the model tier it runs at ([`model-routing.md`](../rules/model-routing.md)), and which skill dispatches it. This makes the fleet legible — when a fan-out skill picks a lens, this is the roster it picks from. Reviewers are **read-only** (they report `FINDING`s per [`orchestration-schemas.md`](orchestration-schemas.md)); only the fixer edits files.

> **Keep this in sync** with `.claude/agents/*.md` frontmatter (`model:` / `effort:`) and with `model-routing.md`. The surface-sync gate counts agents; it does not yet diff this table row-for-row, so update it when you add or retier an agent. (It is a `references/` file, so it is not itself counted as an agent.)

## Persona standard (2026-06-12)

Every agent's opening persona states three load-bearing things — (1) **role + a concrete external standard** (AEA Data Editor, CRAN human review, top-journal referee, back-row-readable), (2) **severity stance** (harsh stances are deliberate on adversarial critics — they counteract agreeableness), (3) **non-goals** (which sibling lens it must not duplicate — the referee-disclaimer pattern). Decoration carries no weight. Skills stay persona-free (they run in the main session; `prompt-shaping.md` covers role). Workstream-B inspections cite this section.

## High-judgment tier — Opus 4.8 (effort: high; `editor` / `methods-referee` / `domain-referee` / `sim-reviewer` pinned at xhigh since 2026-06-11)

A wrong "looks fine" from one of these is expensive (a desk-reject, a hallucinated citation, a biased estimator shipped). Never demote to save cost ([`model-routing.md`](../rules/model-routing.md) anti-pattern).

| Agent | Role | Read/Write | Disposition-aware | Dispatched by |
|---|---|---|---|---|
| `editor` | Desk review, referee selection, editorial synthesis | read-only | selects referee dispositions | `/review-paper --peer` / `--variance` |
| `domain-referee` | Substance referee (contribution, positioning, external validity) | read-only | yes (6-way taxonomy) | `/review-paper --peer` |
| `methods-referee` | Methodology referee (paper-type-aware identification/inference) | read-only | yes (6-way taxonomy) | `/review-paper --peer` |
| `claim-verifier` | Fresh-context CoVe verifier (citations, numbers, novelty) | read-only | no | `/verify-claims`, post-flight in `/lit-review` · `/research-ideation` · `/respond-to-referees` · `/review-paper --peer`; hallucination gate |
| `domain-reviewer` | Field-specific substance review of slides (5 lenses; **template — customize**) | read-only | no | `/slide-excellence`, `/seven-pass-review` (methods lens) |
| `quarto-critic` | Adversarial Beamer↔Quarto parity critic | read-only | no | `/qa-quarto`, `/slide-excellence` (parity) |
| `tikz-reviewer` | Measurement-based TikZ collision/aesthetic audit | read-only | no | `/slide-excellence` (if TikZ), `/extract-tikz`, `/new-diagram` |
| `sim-reviewer` | Monte Carlo review (DGP/estimand, MCSE, coverage-vs-truth) | read-only | no | `/simulation-study` |
| `verifier` | End-to-end compile/render/deploy verification gate | read-only | no | `/commit` |
| `plan-auditor` | Fresh-context fidelity audit: plans vs the user's verbatim interview log (plan mode); dossier claims vs cited project files (dossier mode) | read-only | no | `/analysis-plan`, `/onboard-project` |
| `r-reviewer` | R code quality, reproducibility, idioms (Opus since 2026-06-11 — spec-level net for frontier-drafted code) | read-only | no | `/review-r`, `/slide-excellence` (if R), `/data-analysis-r` |
| `python-reviewer` | Python code quality, reproducibility, pandas/estimation idioms, numerical discipline (Opus since 2026-06-11) | read-only | no | `/review-python`, `/data-analysis-python` |
| `stata-reviewer` | Stata reproducibility, clustering/inference, data-handling traps, esttab, AEA compliance (promoted from Sonnet 2026-06-11 — LLMs weakest on Stata; default estimation language) | read-only | no | `/review-stata`, `/data-analysis-stata` |

## Review / critique tier — Sonnet 4.6, effort: high

| Agent | Role | Read/Write | Dispatched by |
|---|---|---|---|
| `r-package-reviewer` | R package CRAN-readiness (DESCRIPTION/NAMESPACE/roxygen/testthat/policy) | read-only | `/r-package-check` |
| `slide-auditor` | Visual layout audit (overflow, font, spacing) | read-only | `/visual-audit`, `/slide-excellence` |
| `proofreader` | Grammar, typos, overflow, terminology | read-only | `/proofread`, `/slide-excellence`, `/seven-pass-review` (prose lens) |
| `pedagogy-reviewer` | Narrative arc, prerequisites, worked examples, notation, pacing | read-only | `/pedagogy-review`, `/slide-excellence` |
| `humanize-auditor` | AI-voice tell detection (10 categories) | read-only | `/humanize` |

## Apply / translate / vote tier — Sonnet 4.6 (`quarto-fixer`: medium — its safety is the loop, the Opus critic re-audits every round; `beamer-translator` + `promote-memory-council`: high)

| Agent | Role | Read/Write | Dispatched by |
|---|---|---|---|
| `quarto-fixer` | Applies `quarto-critic`'s diffs, re-renders, verifies | **writes** | `/qa-quarto` |
| `beamer-translator` | Beamer→Quarto slide-by-slide translation | **writes** | `/translate-to-quarto` |
| `promote-memory-council` | Five-critic vote on `[LEARN]` promotion (generality/staleness/redundancy/evidence/format) — promoted from Haiku 2026-06-11 (gates persistent memory) | read-only | `/promote-memory` |

## Mechanical tier — Haiku 4.5

Currently no standing agent is pinned to Haiku (the `promote-memory-council` was promoted to Sonnet on 2026-06-11). Haiku remains the target tier for mechanical fix-application subtasks that skills dispatch inline (TikZ extraction, bib-format rewrites, search-and-replace) per `model-routing.md`.

## The referee disposition taxonomy

Only the referees (`domain-referee`, `methods-referee`) and the `editor` that assigns them are disposition-aware. The 6-way taxonomy: **STRUCTURAL · CREDIBILITY · MEASUREMENT · POLICY · THEORY · SKEPTIC**. `--peer` samples 2; `--variance N` samples N (with replacement, ≥1 SKEPTIC when N≥3); `--stress` forces SKEPTIC×2. Dispositions are fixed in the `RUN_CONFIG` before launch (referees are forked and cannot be re-prompted mid-run).

## Cross-references

- [`.claude/rules/model-routing.md`](../rules/model-routing.md) — the tiering rationale + the do-not-demote anti-pattern.
- [`.claude/rules/orchestrator-protocol.md`](../rules/orchestrator-protocol.md) — how the fleet is fanned out, reduced, and judged.
- [`.claude/references/orchestration-schemas.md`](orchestration-schemas.md) — the `FINDING`/`SCORECARD` shape every reviewer returns.
