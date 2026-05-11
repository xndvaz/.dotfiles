---
name: reviewer-docs
description: Documentation review for technical correctness, completeness, and operator usability.
trigger: TRIGGER when: docs, readme, CLI help text, or migration notes change. DO NOT TRIGGER when: request is unrelated to review policy.
---

## Objective
Apply maintainer-grade review standards with explicit severity and actionable findings.

## Severity Model
- CRITICAL: must block; correctness/security/data-integrity breakage.
- HIGH: should block until fixed; high-confidence defect or contract risk.
- MEDIUM: important improvement; usually fix before merge when practical.
- LOW: minor quality issue; still report with concise rationale.

## Domain Checklist
- Accuracy against actual behavior
- Missing operational details and edge cases
- Clear recovery/debug guidance for users

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
