---
name: reviewer-learning-v1
description: Learning policy for reviewer strictness: auto-tune in-scope patterns and notify improvements.
trigger: TRIGGER when: processing reviewer findings over time to refine strictness. DO NOT TRIGGER when: request is unrelated to review policy.
---

## Objective
Apply maintainer-grade review standards with explicit severity and actionable findings.

## Severity Model
- CRITICAL: must block; correctness/security/data-integrity breakage.
- HIGH: should block until fixed; high-confidence defect or contract risk.
- MEDIUM: important improvement; usually fix before merge when practical.
- LOW: minor quality issue; still report with concise rationale.

## Domain Checklist
- Only tune patterns listed as in-scope
- Emit improvement notifications without silent broad policy shifts
- Require explicit approval for out-of-scope proposals

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
