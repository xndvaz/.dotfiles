# Codex Global Guide (Dotfiles)

## Scope
This file is intended to be symlinked to `~/.codex/AGENTS.md`.
Use it as baseline guidance across repositories.

## Commit and Signing Policy
- Use Conventional Commits in lowercase: `type(scope): description`.
- Scope is mandatory.
- Never bypass signing with `--no-gpg-sign`.
- Before `git push`, verify the latest commit signature with:
  - `git log --show-signature -1`
- If a rebase produced unsigned commits, re-sign before push.

## Review Policy
- Run maintainer-grade review before finalizing substantial changes.
- Review skills follow `reviewer-<domain>` naming.
- Non-review skills keep descriptive names without `reviewer-` prefix.
- Default order:
  1. `reviewer-general`
  2. `reviewer-security` when boundaries/input/auth/files are touched
  3. Language/domain reviewer when applicable (for example `reviewer-python`, `reviewer-go`)
- Pre-commit reviewer gate is fail-closed: any finding blocks commit.

## Python Disambiguation
- Use `reviewer-python` as router.
- Route to `reviewer-python-scientific` for numerical/scientific stacks.
- Route to `reviewer-python-general` for service/app/automation stacks.

## Reviewer Learning v1
- Learning mode: auto-tune in-scope patterns and notify improvements.
- Out-of-scope tuning proposals require explicit user approval before applying.
- Notifications are written to local learning logs, not committed by default.

## Language Policy
- Repository files: en-US.
- User-facing response language: user-selected (default follows user input language).

## Roadmap Note
- `codex_hooks` is tracked as future capability. Keep current workflows hook-based until stable support is available.
