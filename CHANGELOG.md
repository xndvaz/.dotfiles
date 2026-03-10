# Changelog

All notable changes to this repository are documented in this file.

The format is inspired by Keep a Changelog and this project uses semantic version tags
(`vMAJOR.MINOR.PATCH`) for releases.

## [Unreleased]

### Added

- GitHub Actions CI workflow with shell quality gates (`bash -n`, `shellcheck`, `shfmt -d`).
- Installer CLI smoke test matrix in `scripts/test-install-flags.sh`.
- `--dry-run` support in `scripts/install.sh`.
- `--dry-run` support in `scripts/doctor.sh`.

### Changed

- Improved SSH agent diagnostics in `doctor.sh` when a socket exists but `ssh-add -L` fails.
- Documented release/tag flow and changelog usage in `README.md`.
