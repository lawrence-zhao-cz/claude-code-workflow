---
name: review-stata
description: Read-only Stata code review protocol for `.do` scripts. Checks reproducibility scaffolding, clustering/inference discipline, Stata data-handling traps, esttab table emission, and AEA replication compliance; produces a report without editing. Use when user says "review this do-file", "check the Stata code", "audit the .do", "code review on the Stata", or when a `.do` file is touched as part of a paper submission. NOT for running the code — pair with `/audit-reproducibility` for numeric verification.
argument-hint: "[filename or 'all' or a directory]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Task"]
---

# Review Stata Scripts

Run the comprehensive Stata code review protocol. The Stata analogue of `/review-r` and `/review-python` (closes the gap the `stata-code-conventions.md` enforcement note flagged).

## Steps

1. **Identify scripts to review:**
   - If `$ARGUMENTS` is a specific `.do` filename: review that file only.
   - If `$ARGUMENTS` is a directory: review all `.do` scripts under it.
   - If `$ARGUMENTS` is `all`: review all Stata scripts in `scripts/stata/` and `Figures/*/`.

2. **For each script, launch the `stata-reviewer` agent** with instructions to:
   - Follow the full protocol in the agent instructions.
   - Read `.claude/rules/stata-code-conventions.md` for current standards.
   - Save report to `quality_reports/[script_name]_stata_review.md`.

3. **After all reviews complete**, present a summary:
   - Total issues per script.
   - Breakdown by severity (Critical / High / Medium / Low).
   - Top 3 most critical issues (clustering/inference and data-handling traps rank first).

4. **IMPORTANT: Do NOT edit any Stata source files.** Only produce reports. Fixes are applied after user review.
