---
name: analysis-plan
description: Create and maintain the living analysis plan — the single source of truth for what gets cleaned, estimated, and tabulated in a project. Turns a research idea (or an /interview-me spec) plus REAL data into a structured document of cleaning filters, a specification table (R1, R2, …), and an output registry that the pipeline skills execute by ID; a forked plan-auditor verifies the draft against your verbatim words. Use when user says "make an analysis plan", "plan the regressions", "turn this idea into a game plan", "log this ad-hoc regression", "amend the plan", or before any multi-spec analysis. The intent-fidelity (error-1) gate of the replication layer.
argument-hint: "[project-slug or idea/spec pointer] [--amend] [--log-adhoc] [--no-verify]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task"]
---

# `/analysis-plan` — the living analysis plan

Produce and maintain `scripts/analysis_plans/<slug>.md`: the **authoritative, human-approved contract** between your research intent and everything downstream. The pipeline skills (`/data-analysis-r|python|stata`) execute specs from it **by ID**; the code reviewers check code against its rows instead of the script's self-written comments; `/cross-check` re-implements from it — which makes intent errors (Fable misreading your ask) visible to layers that are otherwise structurally blind to them.

**Why this exists:** an intent error produces code that is wrong *and* internally consistent — reviewers checking code-vs-its-own-header find harmony, and `/cross-check` faithfully reproduces the misread spec in a second language. The only place intent can be verified is against **your words**, by **you** (approving this document) and by the **`plan-auditor`** (reading your verbatim answers in a fresh context).

## Relationship to its siblings

- [`/interview-me`](../interview-me/SKILL.md) — the abstract front-end (RQ, hypotheses, identification). Its spec is an *input* here, not a substitute: the analysis plan is written only once real data is inspectable.
- [`/preregister`](../preregister/SKILL.md) — can consume this plan as the PAP's specification section.
- The plan chains forward: spec IDs → output registry → `passport.yaml` claims → the replication package's exhibit map.

## The plan document

Lives at `scripts/analysis_plans/<slug>.md` (**committed** — it belongs in the replication package). Sections:

```markdown
# Analysis Plan: <project>
**Status:** DRAFT | ACTIVE | FROZEN   **Last amended:** YYYY-MM-DD (§5)
**Interview spec:** [path or "none"]   **Data:** [sources + vintage]
**Language roles:** prep=.. estimate=.. cross-check=..

## 1. Data prep
Filters  F1: [e.g. drop obs with missing county FIPS]  F2: …
Variables V1: [name = definition, source column(s)]    V2: …
Expected post-clean N: [...]  (feeds the 02_clean validation battery)

## 2. Specifications
| ID | Status | Outcome | Regressors | FE | Cluster | Sample | Weights | Estimator | Lang | Feeds | Notes |
|----|--------|---------|------------|----|---------|--------|---------|-----------|------|-------|-------|
| R1 | PLANNED | … | … | … | … | … | … | … | stata | T1 | … |
Status ∈ PLANNED / RUN / ARCHIVED / PROMOTED.  Main specs R#; ad-hoc specs A# (§4).

## 3. Output registry
| Exhibit | Specs | Output file | Status |
|---------|-------|-------------|--------|
| T1 | R1–R3 | scripts/stata/_outputs/tab_main.tex | … |

## 4. Ad-hoc log
Same columns as §2, IDs A1… + Motivation + Date + Verdict (PROMOTED → R# | ARCHIVED + one-line reason).
This is the memory of everything attempted — nothing runs outside the plan.

## 5. Amendment log
- YYYY-MM-DD: [what changed, why]   (preregistration-style audit trail)
```

## Modes

### Create (default)

1. **Pre-Flight data inventory first** — same contract as the pipeline skills: read the actual data (variables, dtypes, N, missingness). If no data is readable, stop: this skill is for *actionable* plans; use `/interview-me` for the idea stage.
2. Load the `/interview-me` spec if one exists — build on it, don't re-ask.
3. Conduct a **short, focused interview** (conversational, one or two questions per turn — same style as `/interview-me`): exact filters, the specs to estimate (outcome/regressors/FE/cluster/sample/weights/estimator/language per row), and which exhibits each feeds.
4. **Append every verbatim user answer to `scripts/analysis_plans/<slug>_interview_log.md` as it arrives** (dated). This log is the `plan-auditor`'s source material and the durable record of intent — never paraphrase into it.
5. Draft the plan document.
6. **Fidelity audit** (unless `--no-verify`): spawn `plan-auditor` via `Task` with `context: fork` — hand it the plan path + the interview-log path, **never this conversation's drafting context**. Reconcile per `post-flight-verification.md` semantics: fix `DIVERGES`/`OMISSION` findings; present `UNSUPPORTED-ADDITION`s to the user for explicit keep/drop sign-off (they may be good suggestions — never silently delete or silently keep).
7. Present for the user's edit/approval. **The user's approval of this document is the intent gate** — status moves DRAFT → ACTIVE.

### `--amend` (the living-document cycle)

Document first, code second — the single-source-of-truth discipline (`single-source-of-truth.md`):

1. Capture the user's amendment request **verbatim** into the interview log (dated).
2. Edit the plan (spec rows, filters, registry); append a §5 entry.
3. Re-run the fidelity audit **on the changed rows only**.
4. Only then touch pipeline code. A pipeline skill asked to deviate from the plan must route through here — never silently diverge.

### `--log-adhoc` (the 30-second path)

For one-off exploratory regressions — rigor without friction:

1. One-line description from the user → one new `A#` row in §4 (verbatim line into the interview log; no interview, no audit).
2. The pipeline skill runs it like any spec; results recorded; verdict later: `PROMOTED → R#` (it's going in the paper — promote via `--amend` so it gets the audit) or `ARCHIVED` with a one-line reason.

Nothing runs outside the plan: an ad-hoc that returns something interesting is already logged, already reproducible, already part of the record.

### `--no-verify`

Skips the `plan-auditor` pass (per the `post-flight-verification.md` opt-out convention). The user-approval gate still applies.

## Anti-patterns

- **Paraphrasing into the interview log.** The auditor's value is independence from Fable's interpretation; the log must be the user's words.
- **Code-first amendments.** Changing a spec in `03_analyze` and back-filling the plan later defeats the contract.
- **Treating ARCHIVED as deleted.** Archived rows stay — the plan remembers what was attempted and why it was set aside.
- **Plan sprawl.** One plan per project slug; tens of specs is fine, parallel half-plans are not.

## Cross-references

- [`.claude/agents/plan-auditor.md`](../../agents/plan-auditor.md) — the forked fidelity verifier.
- [`.claude/rules/single-source-of-truth.md`](../../rules/single-source-of-truth.md) — the plan is authoritative for analyses.
- [`.claude/rules/post-flight-verification.md`](../../rules/post-flight-verification.md) — the CoVe fork pattern this reuses.
- [`.claude/skills/data-analysis-r/SKILL.md`](../data-analysis-r/SKILL.md) · [`.claude/skills/data-analysis-python/SKILL.md`](../data-analysis-python/SKILL.md) · [`.claude/skills/data-analysis-stata/SKILL.md`](../data-analysis-stata/SKILL.md) — the executors.
- [`.claude/skills/cross-check/SKILL.md`](../cross-check/SKILL.md) — re-implements from plan rows when a plan exists.
- [`.claude/rules/replication-protocol.md`](../../rules/replication-protocol.md) — the plan is the spec layer above the tolerance contract.

## Onboarded projects (dossier-aware)

If `scripts/analysis_plans/<slug>_dossier.md` exists ([`/onboard-project`](../onboard-project/SKILL.md)): import its already-run specifications as plan rows — Status `RUN` with output paths where outputs exist, else `A#` rows marked *attempted pre-onboarding* (the §4 memory extends backward in time). Interview only the dossier's gaps; confirmed dossier answers enter the interview log as `[from dossier: file:line]`.
