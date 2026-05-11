# Project Context

## What this repository is
A personal macOS dotfiles repository that doubles as a reference implementation for automation/review patterns reused in other repositories.

## Main tools used
- `zsh` modules in `shell/`
- `bash` automation in `scripts/` (`install.sh`, `doctor.sh`, smoke suites including pre-commit gate, hooks)
- Codex global bootstrap assets in `codex/`
- Reviewer skills in `skills/`
- VS Code baseline in `vscode/`
- Git templates and release tooling in `git/`
- Homebrew for macOS bootstrap dependencies

## Goals
- Keep workstation setup reproducible and idempotent.
- Keep behavior explicit and auditable (no hidden automation).
- Keep install/doctor safe in interactive and non-interactive/headless flows.
- Keep VS Code extension baseline enforceable in doctor fix mode.
- Keep maintainer-grade review quality via fail-closed pre-commit automation.
- Keep CI split by concern for fast debugging (`lint/format`, `tests`, `security`).
- Keep release automation traceable through tags and generated release notes.

## Constraints
- Primary target is macOS (no Windows installer/doctor in this baseline).
- Shell/bootstrap path resolution must remain location-independent.
- CLI/documentation/test parity is required for installer/doctor flags.
- Dry-run modes must not mutate user files or global git state.
- Bounded filesystem lookups are required for startup/doctor responsiveness.
- Repository files are en-US; user-facing chat language is user-selected.
