# Conventions

## Coding style rules
- Follow `.editorconfig` defaults:
  - UTF-8, LF endings, final newline
  - spaces for indentation
  - 2-space indent by default, 4 spaces for Python files
- Follow `.prettierrc` for Prettier-managed files.
- For shell scripts, prefer:
  - `#!/usr/bin/env bash`
  - `set -euo pipefail`
  - explicit function names and defensive checks

## Repository organization rules
- Keep concerns separated by top-level directory:
  - `scripts/` for automation and diagnostics
  - `scripts/hooks/` for global git hooks
  - `shell/` for runtime shell modules
  - `vscode/` for editor baseline
  - `git/` for git templates/tooling
  - `codex/` for Codex global assets
  - `skills/` for reviewer skills (`reviewer-<domain>`)
  - `docs/` for human-oriented operational docs
  - `slides/` for Reveal.js templates/themes
- Preserve deterministic shell load order via numeric prefixes.
- Keep bootstrap/install/doctor location-independent and idempotent.
- Keep installer/doctor CLI behavior explicit and predictable in non-TTY mode.
- Keep doctor extension hygiene explicit: `doctor --fix` may prune VS Code extensions to `vscode/extensions.txt`, while `--dry-run` only reports planned removals.
- Prefer bounded filesystem lookups over recursive scans in startup/doctor paths.
- Keep local and CI quality gates aligned.

## CI workflow conventions
- Keep workflows split by concern:
  - `ci-lint-format`
  - `ci-tests`
  - `ci-security`
  - `release`
- Avoid monolithic CI files that mix unrelated failure domains.

## Review automation conventions
- Pre-commit reviewer gate is fail-closed.
- Any reviewer finding blocks commit.
- Reviewer naming contract: `reviewer-<domain>`.
- `reviewer-python` acts as router to general vs scientific reviewer.
- Learning v1 may auto-tune only in-scope patterns and must log improvement notifications.
- Out-of-scope learning proposals must be approval-required.

## Documentation and language
- Repository files must be written in en-US.
- User chat language is user-selected and can differ from repository language.
- Update `README.md`, docs, and `.ai/decisions.md` together when behavior changes are user-visible.
