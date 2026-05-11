# Using Reviewer Skills (Codex)

Skills live under `skills/`.
Only review-oriented skills follow the naming contract `reviewer-<domain>`.
Non-review skills should keep descriptive names without the `reviewer-` prefix.

## Core skills
- `reviewer-general`
- `reviewer-security`
- `reviewer-shell`
- `reviewer-dotfiles`
- `reviewer-python` (router)
- `reviewer-go`

## Extended skills
- `reviewer-architecture`
- `reviewer-api-compat`
- `reviewer-ci-release`
- `reviewer-performance`
- `reviewer-python-scientific`
- `reviewer-php-wordpress`
- `reviewer-node-workflow`
- `reviewer-docs`
- `reviewer-maintainability`
- `reviewer-release`
- `reviewer-dependencies`
- `reviewer-learning-v1`

## Python routing
Use `reviewer-python` first. It routes review to:
- `reviewer-python-general` for service/app/automation Python
- `reviewer-python-scientific` for numerical/scientific stacks

## Severity contract
Each reviewer reports with this machine-readable shape:

```text
VERDICT: PASS|FAIL
FINDINGS: <integer>
SEVERITY_COUNTS: CRITICAL=<n> HIGH=<n> MEDIUM=<n> LOW=<n>
- [SEVERITY] path:line - concise issue
```

## Reviewer learning v1
Policy files:
- `.ai/reviewer-learning/policy.toml`
- `.ai/reviewer-learning/in-scope-patterns.txt`

Runtime local state (not committed):
- `$HOME/.ai/reviewer-learning/state.tsv`
- `$HOME/.ai/reviewer-learning/notifications.log`
- `$HOME/.ai/reviewer-learning/proposals.log`

Guardrails:
- auto-tune only for in-scope patterns
- notify on improvements
- out-of-scope changes are approval-required

## codex_hooks roadmap
`codex_hooks` remains under development in Codex CLI.
Current enforcement is implemented via `scripts/hooks/pre-commit`.
