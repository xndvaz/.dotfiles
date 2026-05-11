# xndvaz/.dotfiles

A reproducible, macOS-first dotfiles baseline focused on explicit behavior, idempotent setup, and Codex-first review automation.

## Repository layout

| Path | Purpose |
| --- | --- |
| `.ai/` | machine-readable project context, conventions, and decisions |
| `.github/workflows/` | split CI workflows (`lint/format`, `tests`, `security`) and `release` |
| `codex/` | Codex global config and AGENTS guidance |
| `docs/` | human docs (`git-cliff`, skills usage, test catalog) |
| `git/` | commit template, gitconfig template, git-cliff config |
| `scripts/` | installer, doctor, smoke tests, reviewer learning helper |
| `scripts/hooks/` | global git hooks (pre-commit reviewer gate) |
| `shell/` | shell modules plus `bashrc` bootstrap |
| `skills/` | `reviewer-<domain>` skill set |
| `slides/` | Reveal.js templates and themes |
| `vscode/` | settings, keybindings, extension baseline |
| `zshrc.bootstrap` | location-independent shell entrypoint |

## Quick start (macOS)

```bash
git clone https://github.com/xndvaz/.dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
make install
```

Dry-run preview:

```bash
make dry-run
```

Validation:

```bash
make doctor
bash scripts/test-pre-commit-gate.sh
```

## Make targets

- `make install`: run installer
- `make dry-run`: installer dry-run mode
- `make doctor`: diagnostics
- `make doctor-fix`: diagnostics with fix mode
- `make update`: fast-forward pull + non-interactive install

## Installer and doctor behavior

### Installer (`scripts/install.sh`)

Supported automation flags:
- `--non-interactive`
- `--dry-run`
- `--strict-extensions`
- `--configure-signing=<yes|no|prompt>`
- `--configure-identity=<yes|no|prompt>`
- `--signing-key="<algo pubkey>"`
- `--git-name="<name>"`
- `--git-email="<email>"`

Key actions:
- links `~/.zshrc` and `~/.bashrc`
- links VS Code settings/keybindings
- installs baseline VS Code extensions
- links Codex config (`~/.codex/AGENTS.md`, `~/.codex/config.toml`, `~/.codex/skills`)
- installs required tooling on macOS (`gh`, `node`, `shellcheck`, `git-cliff`, `go`)
- configures git editor, commit template, hooksPath, signing/identity (optional flows)
- renders `~/.gitconfig` from `git/config.template` when required values exist
- ensures `~/.ssh/allowed_signers` entry for git SSH signature verification
- runs doctor at the end

### Doctor (`scripts/doctor.sh`)

Supported flags:
- `--fix`
- `--non-interactive`
- `--dry-run`

Checks include:
- symlink correctness (shell, VS Code, Codex)
- VS Code extension baseline drift (`vscode/extensions.txt`)
- shell module readability and script executability
- Homebrew and PATH hygiene
- required tooling availability
- SSH agent and key visibility
- git editor/template/hooks/signing/allowed signers

Fix behavior:
- `doctor --fix` prunes VS Code extensions not present in `vscode/extensions.txt`
- `doctor --fix --dry-run` only reports planned extension removals

## Codex-first review system

- global hook path is set to `scripts/hooks`
- `scripts/hooks/pre-commit` runs:
  1. staged shellcheck
  2. formatter-policy signal for Python repos (Ruff-first baseline, Black detection signal)
  3. Codex maintainer-grade reviewer gate (fail-closed)
- any reviewer finding blocks commit
- reviewer execution failure blocks commit (fail-closed)
- reviewer-learning v1 updates local learning state and emits improvement notifications

Skill docs: `docs/using-skills.md`

## VS Code baseline

Highlights:
- Ruff-first Python formatter baseline
- explicit code actions on save (`organizeImports` and `fixAll`)
- YAML formatter via Prettier
- Python analysis (`typeCheckingMode=basic`, auto-import completions)
- MCP discovery enabled
- existing visual/editor ergonomics preserved

Extensions baseline is in `vscode/extensions.txt`.

## Slides baseline (Reveal.js)

This repo uses Reveal.js + custom themes instead of Marp.

- template: `slides/template.html`
- themes: `slides/themes/default`, `slides/themes/contrast`
- scaffold helper: `slides/new-deck.sh`

Create a deck:

```bash
bash slides/new-deck.sh roadmap default
```

## CI and release workflows

- `ci-lint-format.yml`: syntax, shellcheck, shfmt
- `ci-tests.yml`: smoke suites (install/doctor/doctor-vscode-prune/pre-commit gate) + doctor/install dry-run checks
- `ci-security.yml`: shell SAST, secret scanning, policy grep
- `release.yml`: tag-driven release notes with `git-cliff`

## Reference docs

- `docs/git-cliff.md`
- `docs/using-skills.md`
- `docs/test-catalog.md`

## Language policy

- repository files (code/docs/config): en-US
- user-facing chat language: user-selected
