# Project Context

## What this repository is
This is a personal dotfiles repository for macOS. It provides a reproducible, modular development environment with explicit configuration and minimal hidden behavior.

## Main tools used
- `zsh` with modular files in `shell/`
- `bash` scripts in `scripts/` (`install.sh`, `doctor.sh`)
- VS Code configuration in `vscode/`
- Git templates/config helpers in `git/`
- Homebrew as the expected package/bootstrap dependency on macOS

## Goals
- Keep workstation setup reproducible across machines.
- Keep configuration readable and easy to audit.
- Keep setup scripts idempotent and safe to re-run.
- Prefer explicit behavior over convenience magic.
- Support both interactive local setup and non-interactive CI/headless bootstrap flows.

## Constraints
- Primary target is macOS.
- Changes should avoid machine-specific hardcoding unless required.
- Existing formatting/tooling rules in `.editorconfig` and `.prettierrc` must be respected.
- Bootstrap/doctor flows should remain reliable for fresh environments.
- Shell/bootstrap path resolution must remain location-independent (no hardcoded `~/.dotfiles` assumptions).
- User-facing installer/doctor CLI behavior must stay consistent with script `--help` output and `README.md`.
