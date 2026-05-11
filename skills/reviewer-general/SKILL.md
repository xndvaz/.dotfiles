---
name: reviewer-general
description: Maintainer-grade general code review for correctness, regressions, and test gaps.
trigger: TRIGGER when: reviewing code changes across any stack. DO NOT TRIGGER when: request is unrelated to review policy.
---

## Objective
Apply maintainer-grade review standards with explicit severity and actionable findings.

## Severity Model
- CRITICAL: must block; correctness/security/data-integrity breakage.
- HIGH: should block until fixed; high-confidence defect or contract risk.
- MEDIUM: important improvement; usually fix before merge when practical.
- LOW: minor quality issue; still report with concise rationale.

## Domain Checklist
- Correctness and behavior regressions
- Security and data safety basics
- Missing tests or weak validation paths

## Output Contract
Return in this shape:

VERDICT: PASS|FAIL
FINDINGS: <integer>
SEVERITY_COUNTS: CRITICAL=<n> HIGH=<n> MEDIUM=<n> LOW=<n>
- [SEVERITY] path:line - concise issue

Rules:
- Any valid finding counts.
- Do not invent issues without evidence.
- Keep suggestions specific and minimal.
