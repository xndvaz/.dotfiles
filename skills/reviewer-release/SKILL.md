---
name: reviewer-release
description: Release readiness review for changelog integrity, tagging, and signing policy compliance.
trigger: TRIGGER when: preparing releases, tags, or release notes. DO NOT TRIGGER when: request is unrelated to review policy.
---

## Objective
Apply maintainer-grade review standards with explicit severity and actionable findings.

## Severity Model
- CRITICAL: must block; correctness/security/data-integrity breakage.
- HIGH: should block until fixed; high-confidence defect or contract risk.
- MEDIUM: important improvement; usually fix before merge when practical.
- LOW: minor quality issue; still report with concise rationale.

## Domain Checklist
- Changelog and commit taxonomy consistency
- Tag strategy and release metadata quality
- Signed commit/tag and verification policy adherence

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
