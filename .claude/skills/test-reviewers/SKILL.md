---
name: test-reviewers
description: Behavioral regression suite for the reviewer/auditor AGENT layer — re-runs the seeded-defect fixtures catalogued in tests/TESTING.md through each gate (r/python/stata-reviewer, proofreader, slide-auditor, plan-auditor, claim-verifier, verifier, /cross-check, /audit-reproducibility, /qa-quarto, dossier audit) BLIND, then has a forked, different-tier judge grade whether the gate NAMED the specific planted defect, runs each row N=3 times for a catch-rate, and diffs the result against a stored baseline to surface regressions (CAUGHT→MISS) after agent-prompt edits or model swaps. Negative-control rows catch the opposite failure — a reviewer that flags a clean fixture. Use when user says "test the reviewers", "run the regression suite", "did my agent edit break a reviewer", "check the gates still catch defects", "regression-test the agent layer", or after editing .claude/agents/* or swapping the model. A SIGNAL, never a commit gate — it is never wired into pre-commit or CI and reports to quality_reports/testing/. Conversational skills are driven by canned inputs. NOT for static frontmatter parity (that is /deep-audit + check-skill-integrity).
argument-hint: "[--gate <name>] [--runs N] [--no-conversational] [--update-baseline] [--strict]"
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Task"]
disable-model-invocation: true
effort: medium
---

# `/test-reviewers` — behavioral regression suite for the agent layer

The deterministic gates (`check-skill-integrity`, `check-surface-sync`) prove the template's *static* shape is consistent. Nothing proves its *behavior*: that after you edit an agent prompt or swap the model, `python-reviewer` still catches a cluster-≠-plan defect, `claim-verifier` still flags the fabricated citation, `/qa-quarto`'s loop still converges. This skill is that missing layer. It re-runs the seeded-defect fixtures through each reviewer/auditor **blind**, judges whether the gate **named the specific defect**, and reports any **regression against a stored baseline**. It is the dynamic complement to [`/deep-audit`](../deep-audit/SKILL.md) (which audits the template statically) — see [`tests/TESTING.md`](../../../tests/TESTING.md) for the fixtures and answer key it runs against.

**Core principle:** this is a **signal, not a gate.** LLM reviewers are stochastic, so a single run is noisy and a green run is never a guarantee. It runs on demand (after agent edits / model swaps / pre-release), never blocks a commit, and its job is to flag *deltas* against a known-good baseline — not to render a verdict.

## When to use

- **After editing a reviewer/auditor agent prompt** (`.claude/agents/*.md`) — confirm the edit didn't blunt the agent's catch-rate.
- **After a model swap or `model-routing` change** — a cheaper tier may silently stop catching subtle defects.
- **After editing a rule a reviewer reads** (e.g. `python-code-conventions.md`) — the agent's behavior is the prompt *plus* the rules it loads.
- **Pre-release** — a full `--runs 5` sweep before tagging a template version.
- **NOT** as a commit/CI gate — see Exit behavior.

## Inputs (flags)

- `--gate <name>` — run only the rows owned by that gate (e.g. `--gate python-reviewer`). Default: all rows. Use this to re-confirm a single gate after fixing its prompt.
- `--runs` — runs per row for the catch-rate (`--runs N`, default **3**). Use `--runs 1` for a fast smoke check, `--runs 5` pre-release.
- `--no-conversational` — skip the canned-input rows (`/interview-me`, `/analysis-plan`); run only the read-only reviewer rows.
- `--update-baseline` — after a run you've confirmed is good, write the current catch-rates as the new baseline. Never combine with a run you haven't eyeballed.
- `--strict` — exit non-zero if any row REGRESSED (for an *optional* manual/cron wrapper). Off by default; even on, this is never wired into pre-commit or CI.

## The test model (the concepts this enforces)

- **A row** = `(fixture, planted-defect id, owning gate, expected verdict)`, sourced from the [`tests/TESTING.md`](../../../tests/TESTING.md) answer key (R1–R3, Y1–Y3, D1–D3, T1/T2, V1, P1–P5, L0–L2, X1/X2, A1–A4, Q1, O1). That file is the **contract**.
- **Specificity is the pass bar.** Verbatim from the answer key: *a row passes only if the gate names the planted defect specifically — a generic "could be improved" does not count.* A vague flag is a MISS.
- **Dual guard.** Positive rows catch a reviewer that flags *nothing*; **negative-control** rows (the faithful plan `L0`, the real citation `P5b`) catch a reviewer that flags *everything*. Both directions are graded.
- **Catch-rate, not a coin flip.** Each row runs N=3 times; CAUGHT means caught in ≥⌈N/2⌉ runs. A suspected regression is **re-run before it is believed**.
- **Regression = delta vs. baseline.** The actionable output is *"`python-reviewer` Y3 went 3/3 → 0/3 since you edited its prompt"* — not the absolute tally.
- **Challenger ≠ oracle.** A MISS implicates the *fixture* too: the defect may have drifted out, or the answer key may be wrong (mirrors [`replication-protocol.md`](../../rules/replication-protocol.md)). Check both the gate and the fixture before fixing the prompt.

## Workflow

This skill is inherently fan-out (per row: dispatch the reviewer, then a judge, ×N). Implement it as a **multi-agent workflow** (one pipeline per row). Phases:

### Phase 0: Scope and load
Parse flags. Build the row list from [`tests/TESTING.md`](../../../tests/TESTING.md): default all rows, or filter by `--gate`. Drop the conversational rows if `--no-conversational`. Load the prior baseline ([`tests/reviewer-baseline.json`](../../../tests/reviewer-baseline.json)) if present. Confirm each fixture exists under [`tests/fixtures/`](../../../tests/fixtures/); a missing fixture is a setup error, not a MISS.

### Phase 1: Run each gate BLIND (×N)
For each row, invoke its owning gate on the fixture **without ever showing it the answer key** — exactly as in production. Spawn the owning agent via `Task` with its real `subagent_type` (e.g. `python-reviewer`, `claim-verifier`, `verifier`, `plan-auditor`). For toolchain rows (`/cross-check`, `/audit-reproducibility`, `/qa-quarto`) run the real skill against the fixture. **Conversational rows** (`/interview-me`, `/analysis-plan`) are driven by a **canned-input file** beside the fixture (the scripted user turns — e.g. an `/analysis-plan` delegation line) so they run unattended. Capture each run's raw output.

### Phase 2: Judge each output (forked, different tier)
For each captured output, spawn a **judge** via `Task` that sees the reviewer's output + the expected defect from the answer key (NOT the original reviewing context) and decides: did the gate **name this specific defect**? The judge **must run on a different tier than the reviewer** ([`model-routing.md`](../../rules/model-routing.md) anti-pattern: a same-tier judge launders correlated blind spots as agreement). Reviewers are Opus → judge on Sonnet. Verdict per run: `CAUGHT` / `MISS`; for negative-control rows, `FALSE-POSITIVE` if the gate flagged the clean fixture. The judge quotes the line it keyed on.

### Phase 3: Aggregate, diff, re-confirm
Reduce N runs to a catch-rate per row. Diff against the baseline → tag each row `STABLE` / `REGRESSION` (CAUGHT→MISS) / `IMPROVED` (MISS→CAUGHT) / `NEW`. **Re-run any suspected REGRESSION** (a fresh N) before reporting it, to filter stochastic noise from a real drop.

### Phase 4: Report (and optionally re-baseline)
Write a dated report to `quality_reports/testing/YYYY-MM-DD_test-reviewers.md`: per-row gate, fixture, expected defect, catch-rate, verdict, baseline-delta, and the judge's keyed quote for every MISS/FALSE-POSITIVE. Lead with the **regressions** (the only actionable part). If `--update-baseline` and the run is clean, rewrite [`tests/reviewer-baseline.json`](../../../tests/reviewer-baseline.json). Never auto-edit `.claude/agents/*` — a MISS is reported for the human to fix, then re-confirmed with `--gate <name>`.

## Canned inputs (conversational rows)

A conversational gate can't run unattended, so its fixture carries a `canned_input.md` (or `.txt`) holding the scripted user turns the skill would otherwise prompt for — e.g. for `/analysis-plan`, a single delegation line; for `/interview-me`, the ordered answers. Phase 1 feeds those verbatim instead of asking. The canned input is part of the fixture and is itself versioned in `tests/TESTING.md`. (The `/analysis-plan` delegation-line row depends on delegation mode existing in that skill — until then, that row uses standard canned interview answers.)

## Output / artifacts

| Artifact | Path | Committed? |
|---|---|---|
| Run report | `quality_reports/testing/YYYY-MM-DD_test-reviewers.md` | No (gitignored, project-internal) |
| Catch-rate baseline | `tests/reviewer-baseline.json` | Yes — it's part of the test contract, beside `TESTING.md` |

## Exit behavior

- **Default:** always exit 0 — it is a report, never a gate. Print the summary + any regressions.
- **`--strict`:** exit non-zero only if a *confirmed* REGRESSION remains after the Phase 3 re-run — for an optional manual/cron wrapper. Still never wired into pre-commit or CI.
- **A missing fixture / unreadable answer key:** stop and report a setup error (exit 2) — do not score it as a MISS.
- Per the [verification-protocol](../../rules/verification-protocol.md), end only after the report is written and the regression list is surfaced.

## Cross-references

- [`tests/TESTING.md`](../../../tests/TESTING.md) — the answer key (defect → owning gate → expected verdict) and the "named specifically" grading rule this skill enforces.
- [`tests/fixtures/`](../../../tests/fixtures/) — the seeded-defect fixtures (toy-panel, toy-paper, toy-plan, seeded-defects, legacy-project) the rows run against.
- [`/deep-audit`](../deep-audit/SKILL.md) — the *static* template audit; this skill is its *dynamic/behavioral* complement.
- [`.claude/rules/model-routing.md`](../../rules/model-routing.md) — the challenger-≠-auditor tier rule the judge obeys.
- [`.claude/rules/replication-protocol.md`](../../rules/replication-protocol.md) — the challenger-≠-oracle framing behind "a MISS implicates the fixture too."
- [`.claude/rules/quality-gates.md`](../../rules/quality-gates.md) — defines "gate"; this skill tests the *agent* gates, not the deterministic ones.
- [`/cross-check`](../cross-check/SKILL.md) · [`/audit-reproducibility`](../audit-reproducibility/SKILL.md) · [`/qa-quarto`](../qa-quarto/SKILL.md) — the toolchain gates whose rows this skill drives.

## What this skill does NOT do

- **Gate commits.** It is a signal; it is never wired into pre-commit or CI, and a green run is not a guarantee (LLM reviewers are stochastic).
- **Auto-fix agent prompts.** A MISS is reported with the judge's rationale; the human edits `.claude/agents/*` and re-confirms with `--gate <name>`.
- **Test the deterministic gates** (`check-surface-sync`, `check-skill-integrity`, `quality_score`) — those are deterministic and covered by their own scripts + CI.
- **Replace `/deep-audit`** — that audits static infrastructure (frontmatter, cross-refs, counts). This audits runtime behavior. They are orthogonal.
- **Diagnose the cause of a regression.** It detects that a gate's catch-rate dropped; localizing why (prompt wording, model tier, a changed rule) is a follow-up.
