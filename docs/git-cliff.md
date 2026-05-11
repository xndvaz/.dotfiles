# git-cliff Guide

This repository uses `git/cliff.toml` for release-note generation from Conventional Commits.
The baseline is intentionally repository-agnostic so it can be reused in other projects.

## Commands

Generate full changelog:

```bash
git cliff -c git/cliff.toml -o CHANGELOG.md
```

Generate notes since latest tag:

```bash
git cliff --latest -c git/cliff.toml -o CHANGELOG.md
```

Preview unreleased notes:

```bash
git cliff --unreleased -c git/cliff.toml
```

## Release workflow
1. Ensure commits follow Conventional Commits.
2. Create and push an annotated tag (`vMAJOR.MINOR.PATCH`).
3. The `release` GitHub workflow publishes release notes using `git-cliff`.

## Reuse as template
- `git/cliff.toml` avoids hardcoded repository URLs by default.
- If a specific project needs clickable commit links, customize the changelog body for that repository only.
