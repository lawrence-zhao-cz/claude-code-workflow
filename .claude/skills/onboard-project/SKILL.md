---
name: onboard-project
description: Intake an EXISTING research project folder (any structure, any life stage, with or without prior Claude use) into this workflow — deep-scan the folder, extract what is known and what was already attempted into a provenance-cited Project Dossier, then migrate non-destructively into a standalone repo cloned from this template. Pre-seeds /interview-me and /analysis-plan so they confirm extracted answers and ask only the gaps; already-run regressions import as plan rows. Use when user says "onboard this project", "convert my old project", "bring this folder into the workflow", "migrate my existing analysis", "I already ran some regressions on this — set it up properly". Never deletes; data never enters git; nothing moves before the migration proposal is approved.
argument-hint: "[path-to-existing-project] [--dry-run] [--no-verify]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task"]
---

# `/onboard-project` — existing-project intake & migration

Turn a messy existing project folder into a standalone, workflow-compatible repo **without losing anything** — files, git history, or the knowledge embedded in old code, notes, and drafts. The output is two artifacts plus a migration: the **Project Dossier** (what is known + what was attempted, every claim with `file:line` provenance) and a clean template-shaped repo whose downstream skills start pre-seeded instead of from zero.

## Hard rules (non-negotiable)

- **Never delete.** Anything not cleanly mappable goes to `_legacy/` (moved, listed in the manifest), not to the void.
- **Data never enters git.** Data files stay on disk, get `.gitignore`d, and are recorded as manifest pointers (source, path, size, vintage) — DCAS practice and the [`confidential-data.md`](../../rules/confidential-data.md) policy.
- **Nothing moves before approval.** Phases 0–3 are read-only on the project; migration executes only after the user approves the proposal. `--dry-run` stops at the proposal permanently.
- **Never auto-run legacy code.** Old scripts run in stale environments and can clobber outputs; first execution happens through the pipeline skills *after* onboarding. If lockfiles exist (renv.lock, requirements.txt, ado lists), record them in the dossier for [`/capture-environment`](../capture-environment/SKILL.md).

## Workflow

### Phase 0: Safety pre-flight (read-only)

1. Resolve the target path; confirm it exists and is a project (not a drive root — refuse suspiciously broad paths).
2. **Prior-onboarding check:** if `quality_reports/onboarding_manifest.md` exists in the target or a previously created repo for this slug, **resume** from the manifest — never duplicate or re-migrate.
3. Git detection: if the folder is a git repo, migration will preserve history (work from a fresh clone; the original checkout is never the workbench). If not, the new repo gets `git init` at Phase 4.
4. **Confidential-data scan** (per `confidential-data.md`): flag PII, restricted/proprietary data, credentials, API keys *before anything is read into context wholesale or copied*. Findings go to the user immediately.

### Phase 1: Deep inventory (read-only)

Walk the tree and classify every file (fan out forked reader subagents via the Task tool for large trees — one per top-level directory):

| Class | What to record |
|---|---|
| **Data** | raw vs intermediate, format, size, apparent source/vintage |
| **Code** | language; entry points; which script produces which output (a dependency sketch); regression calls |
| **Outputs** | figures, tables, logs — and which script made each, where inferable |
| **Docs** | README, notes, paper drafts, **old CLAUDE.md / Claude transcripts** — knowledge gold: *mined* into the dossier, *archived* in `_legacy/`, never blindly merged into the new CLAUDE.md |
| **Env** | renv.lock / requirements.txt / uv.lock / ado lists / .Rprofile |

Infer the **life stage**: idea/data-only → preliminary analysis → drafting → R&R → dormant.

### Phase 2: Knowledge extraction → the Project Dossier

Write `scripts/analysis_plans/<slug>_dossier.md` (destined for the new repo; committed). **Every claim carries `file:line` provenance** — unverifiable statements don't go in. Sections:

1. **Research question / abstract** — from drafts, READMEs, old CLAUDE.md.
2. **Data** — sources, vintages, cleaning steps already applied (parsed from code, not assumed).
3. **Specifications already run** — parsed from the regression code: `outcome | regressors | FE | cluster | sample | weights | estimator | source file:line | outputs found`. **Columns match the analysis-plan §2 table exactly** so rows import losslessly.
4. **Exhibit map** — existing figures/tables ↔ producing scripts.
5. **Gaps & unknowns** — explicitly listed; these become the *new* interview questions downstream.
6. **Stage assessment + recommended entry point** — early: `/interview-me` → `/analysis-plan`; RQ already documented: straight to `/analysis-plan`; drafting-stage: add `/review-paper` + a `passport.yaml`; dormant: a `/coauthor-brief`-style "where it stopped and why" summary.

### Phase 3: Migration proposal — present, then STOP

A migration map the user approves line-by-line:

```
| Old path | New path | Action |
|---|---|---|  (move / copy / gitignore-pointer / archive→_legacy/)
```

Covering: the template layout (`scripts/{python,stata,R}/_outputs/`, `scripts/analysis_plans/`, `paper/`, `Slides/`, `quality_reports/`); `data/` (gitignored, pointers); `_legacy/` for everything unmappable; `.claude/` copied from the hub **recording the hub commit hash in the new CLAUDE.md** (future hub improvements diff in via the CHANGELOG Upgrading flow); CLAUDE.md filled in — project name, **language roles inferred from the observed code**, project-state row.

**`--dry-run` ends here** — inventory + dossier + proposal, zero writes to the project.

### Phase 4: Execute migration (only after explicit approval)

1. Create the standalone repo from the template (at the recorded hub version); fresh clone if the source was a git repo.
2. Apply the approved map; write `quality_reports/onboarding_manifest.md` in the new repo — every old→new mapping, every archive, the data pointers. This manifest is the resume/idempotence anchor.
3. Initial commit (template + migrated files + dossier + manifest; data excluded by `.gitignore`).

### Phase 5: Dossier fidelity audit (unless `--no-verify`)

Spawn [`plan-auditor`](../../agents/plan-auditor.md) in **dossier mode** via `Task` with `context: fork`: it receives the dossier + the original project paths and verifies every extracted claim against its cited provenance (same verdicts: MATCHES / DIVERGES / UNSUPPORTED-ADDITION / OMISSION; same fail-closed rules). An extraction error here would poison every pre-seeded answer downstream — fix DIVERGES/OMISSION findings before handoff.

### Phase 6: Handoff — the pre-seeded interviews

Report the recommended entry point and what's pre-seeded:

- **`/interview-me`** confirms dossier answers ("I found X at `file:line` — correct?") and asks only the gap questions; confirmed answers enter the interview log marked `[from dossier: file:line]`.
- **`/analysis-plan`** imports the already-run specs as plan rows — `RUN` with output paths where outputs exist, else `A#` rows marked *attempted pre-onboarding* — the plan's memory of "everything attempted" extends backward in time.

## Anti-patterns

- **Merging the old CLAUDE.md into the new one.** Mine it into the dossier; archive the original. The new repo follows hub conventions.
- **Tidying data into git "just this once."** Pointers and `.gitignore`, always.
- **Re-running old scripts to "check they still work."** That is the post-onboarding pipeline's job, in a captured environment.
- **Onboarding a half-onboarded project from scratch.** The manifest exists precisely so you resume.

## Cross-references

- [`/interview-me`](../interview-me/SKILL.md) · [`/analysis-plan`](../analysis-plan/SKILL.md) — the pre-seeded consumers.
- [`.claude/agents/plan-auditor.md`](../../agents/plan-auditor.md) — dossier-mode fidelity audit.
- [`.claude/rules/confidential-data.md`](../../rules/confidential-data.md) — the Phase 0 scan policy.
- [`/capture-environment`](../capture-environment/SKILL.md) — snapshot legacy lockfiles post-onboarding.
- [`/coauthor-brief`](../coauthor-brief/SKILL.md) — the dormant-project handoff shape.
