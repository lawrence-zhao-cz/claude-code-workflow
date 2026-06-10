---
name: review-python
description: Read-only Python code review protocol for `.py` analysis scripts. Checks code quality, reproducibility, domain correctness, pandas/estimation idioms, numerical discipline, and professional standards; produces a report without editing. Use when user says "review this Python script", "check the Python code", "audit the analysis code", "code review on the .py", or when a Python file is touched as part of a paper submission. NOT for running the code — pair with `/audit-reproducibility` for numeric verification.
argument-hint: "[filename or 'all' or a directory]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Task"]
---

# Review Python Scripts

Run the comprehensive Python code review protocol.

## Steps

1. **Identify scripts to review:**
   - If `$ARGUMENTS` is a specific `.py` filename: review that file only.
   - If `$ARGUMENTS` is a directory: review all `.py` scripts under it.
   - If `$ARGUMENTS` is `all`: review all Python scripts in `scripts/python/` and `Figures/*/`.

2. **For each script, launch the `python-reviewer` agent** with instructions to:
   - Follow the full protocol in the agent instructions.
   - Read `.claude/rules/python-code-conventions.md` for current standards.
   - Save report to `quality_reports/[script_name]_python_review.md`.

3. **After all reviews complete**, present a summary:
   - Total issues per script.
   - Breakdown by severity (Critical / High / Medium / Low).
   - Top 3 most critical issues.

4. **IMPORTANT: Do NOT edit any Python source files.** Only produce reports. Fixes are applied after user review.
