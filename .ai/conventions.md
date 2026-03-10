# Conventions

## Coding style rules
- Follow `.editorconfig` defaults:
  - UTF-8, LF endings, final newline
  - spaces for indentation
  - 2-space indent by default, 4 spaces for Python files
- Follow `.prettierrc` for files managed by Prettier:
  - single quotes
  - semicolons
  - trailing commas where valid
  - max line width 100
- For shell scripts, prefer:
  - `#!/usr/bin/env bash`
  - `set -euo pipefail` when appropriate
  - clear function names and defensive checks

## Repository organization rules
- Keep top-level concerns separated by folder:
  - `scripts/` for automation and diagnostics
  - `shell/` for shell runtime modules
  - `vscode/` for editor configuration
  - `git/` for Git templates/helpers
- Preserve deterministic shell load order via numeric prefixes in `shell/`.
- Keep bootstrap and doctor scripts location-independent and safe to rerun.
- Keep `install.sh` / `doctor.sh` interactive and non-interactive behaviors explicit and predictable (avoid hidden prompts in non-TTY contexts).
- Prefer bounded filesystem lookups over recursive scans in startup/doctor paths (for example socket discovery) to avoid hangs on large macOS container directories.
- Keep shell quality gates aligned between local checks and CI (`bash -n`, `shellcheck`, `shfmt -d`, installer smoke tests, doctor non-interactive run).
- Keep smoke tests scenario-focused:
  - `test-install-flags.sh` for installer CLI semantics and dry-run behavior
  - `test-doctor-flags.sh` for doctor CLI semantics and dry-run behavior

## Guidelines for adding new files
- Place files in the most specific existing directory before creating new top-level folders.
- Name files by concern and purpose (for example `50-tooling.zsh`).
- Add brief header comments only when behavior is non-obvious.
- When introducing a new pattern or architectural change, record it in `.ai/decisions.md`.
- Update `README.md` when a new file changes user-facing setup behavior.
- When changing installer/doctor CLI semantics, update all of the following in the same change: script `--help`, `README.md`, smoke tests, and `.ai/decisions.md`.
- When preparing a release, update `CHANGELOG.md` first and then create an annotated Git tag from `main`.
