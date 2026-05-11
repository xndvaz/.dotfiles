---
name: reviewer-shell
description: Shell script review for reliability, idempotency, and safe non-interactive behavior.
trigger: TRIGGER when: reviewing bash/zsh scripts or shell hooks. DO NOT TRIGGER when: request is unrelated to review policy.
---

## Objective
Apply maintainer-grade review standards with explicit severity and actionable findings.

## Severity Model
- CRITICAL: must block; correctness/security/data-integrity breakage.
- HIGH: should block until fixed; high-confidence defect or contract risk.
- MEDIUM: important improvement; usually fix before merge when practical.
- LOW: minor quality issue; still report with concise rationale.

## Domain Checklist
- Strict mode and defensive error handling
- Idempotent filesystem and config operations
- Headless/non-interactive safety and dry-run correctness

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
