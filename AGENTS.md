# Agent Guide

## Project overview
This repository provides reproducible macOS dotfiles with explicit, idempotent automation.
It is also used as a reference baseline for patterns reused in other repositories.

## Repository structure
- `scripts/`: setup, diagnostics, smoke tests (install/doctor/pre-commit gate), and reviewer-learning helper scripts
- `scripts/hooks/`: global git hooks (pre-commit reviewer gate)
- `shell/`: ordered Zsh modules plus `bashrc` bootstrap
- `vscode/`: editor settings, keybindings, and extensions baseline
- `git/`: git templates/config (`commit-template`, `config.template`, `cliff.toml`)
- `codex/`: Codex global guidance/config linked into `~/.codex/`
- `skills/`: `reviewer-<domain>` skill set
- `docs/`: human docs (`git-cliff`, skills usage, test catalog)
- `slides/`: Reveal.js templates and themes
- `zshrc.bootstrap`: location-independent shell entrypoint

## Current behavior notes
- `zshrc.bootstrap` must remain location-independent; do not hardcode `~/.dotfiles`.
- `scripts/install.sh` CLI contracts must stay aligned with README/help/tests for:
  - `--non-interactive`, `--dry-run`, `--strict-extensions`,
  - `--configure-signing`, `--configure-identity`,
  - `--signing-key`, `--git-name`, `--git-email`.
- Installer dry-run must not mutate user files or global git config.
- Installer non-interactive mode must propagate to post-install doctor execution.
- `scripts/doctor.sh` must remain headless-safe (`--non-interactive`, no forced GUI launch).
- `scripts/doctor.sh --fix` prunes VS Code extensions outside `vscode/extensions.txt`; `--dry-run` must only report planned removals.
- Doctor dry-run must not apply filesystem/git/environment fixes.
- 1Password socket detection must stay bounded (no recursive scans under Group Containers).
- Pre-commit reviewer gate is fail-closed: any finding blocks commit.
- Keep workflow split (`ci-lint-format`, `ci-tests`, `ci-security`, `release`) and aligned with local behavior.

## Required reads before changes
Read and follow:
- `.ai/context.md`
- `.ai/conventions.md`
- `.ai/decisions.md`

Priority on conflict:
1. `.ai/conventions.md`
2. `.ai/context.md`
3. `.ai/decisions.md`

## Mandatory workflow
Before changing code/config:
1. Inspect current implementation and relevant scripts/docs.
2. Preserve reproducibility and idempotency with minimal scoped changes.
3. Update `.ai/decisions.md` when introducing significant technical decisions.
4. Run quick validations for touched scripts (`bash -n`, smoke suites, and relevant non-interactive/dry-run flows).
