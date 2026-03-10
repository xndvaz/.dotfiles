# Agent Guide

## Project overview
This repository contains reproducible macOS dotfiles for a development environment centered on:
- modular Zsh configuration
- VS Code settings and extension lists
- bootstrap and diagnostics scripts

The goal is explicit, readable, idempotent configuration rather than hidden automation.

## Repository structure
- `scripts/`: setup and validation scripts (`install.sh`, `doctor.sh`)
- `shell/`: ordered Zsh modules (`10-base.zsh`, `20-exports.zsh`, etc.)
- `vscode/`: editor settings, keybindings, and extensions list
- `git/`: Git-related templates (for example commit template)
- `zshrc.bootstrap`: minimal loader for shell modules

## Current behavior notes
- `zshrc.bootstrap` resolves module paths relative to itself (location-independent clone path).
- `scripts/install.sh` supports interactive and non-interactive modes, with explicit CI flags (for example `--strict-extensions`, `--configure-signing`, `--configure-identity`, `--signing-key`).
- `scripts/doctor.sh` supports `--non-interactive` and avoids GUI auto-open actions in headless/non-TTY execution.

## Required reads before changes
Agents must read and follow the files in `.ai/` before making edits:
- `.ai/context.md`
- `.ai/conventions.md`
- `.ai/decisions.md`

If guidance conflicts, prioritize:
1. `.ai/conventions.md` for style and structure
2. `.ai/context.md` for goals and constraints
3. `.ai/decisions.md` for historical decisions and rationale

## Mandatory workflow
Before changing code or configuration, agents must analyze the repository:
1. Inspect relevant files and current behavior.
2. Check existing conventions and decision history in `.ai/`.
3. Make minimal, scoped changes that preserve reproducibility and idempotency.
4. Update `.ai/decisions.md` when introducing a significant technical decision.
