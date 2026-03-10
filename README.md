# 🛠 xndvaz/.dotfiles

> A layered, reproducible macOS development foundation.

This repository contains a modular VS Code + ZSH setup designed for
clarity, consistency, and long-term maintainability.

No hidden automation. No black-box scripts. No machine-specific hacks.

Just explicit, readable infrastructure.

---

# 🧠 Philosophy

This setup prioritizes:

- 🧱 Structure over improvisation
- 🎯 Explicit formatting rules
- 🧩 Modular shell architecture
- 🔁 Reproducibility across machines
- 🔐 Signed commits (optional bootstrap)
- 🧼 Minimalism without fragility

Readable files, explicit behavior, and repeatable bootstrap.

---

# 📌 Who This Is For

This setup can be useful if you:

- Want a clean starting point for macOS development
- Prefer explicit configuration over automation magic
- Care about formatting consistency
- Like modular shell architecture
- Want something reproducible across machines
- Want GitHub "Verified" commit signatures using SSH

You can use it as-is, fork it, or adapt parts of it.

It's a foundation — not a rigid framework.

---

# 🏗 Architecture

```text
<dotfiles-repo-root>
├── .ai/
│   ├── context.md                → Project goals and constraints
│   ├── conventions.md            → Code and workflow conventions
│   └── decisions.md              → Technical decision log
├── .github/
│   └── workflows/
│       └── ci.yml                → Shell quality gates
├── git/
│   └── commit-template           → Commit message template
├── scripts/
│   ├── install.sh                → Bootstrap + environment provisioning
│   ├── doctor.sh                 → Environment diagnostics & validation
│   └── test-install-flags.sh     → Installer CLI smoke tests
├── shell/
│   ├── 10-base.zsh               → Core shell behavior
│   ├── 20-exports.zsh            → Environment variables & SSH agent preference
│   ├── 30-paths.zsh              → Homebrew-aware PATH management
│   └── 40-aliases.zsh            → Command shortcuts
├── vscode/
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt
├── AGENTS.md                     → Repository agent operating rules
├── CHANGELOG.md                  → Release notes history
├── LICENCE                       → License text
├── README.md                     → Project overview and onboarding
├── .editorconfig                 → Cross-tool formatting baseline
├── .prettierrc                   → Explicit formatting rules
├── .prettierignore
└── zshrc.bootstrap               → Minimal shell loader
```

---

## 🧩 Editor Layer

Controls formatting engines, UI ergonomics, and behavior.

- Explicit default formatters
- Controlled Prettier behavior (`requireConfig`)
- Stable visual rules (ruler, whitespace, cursor behavior)
- Minimal noise, predictable output

---

## 🐚 Shell Layer

ZSH configuration is modular — not a monolithic `.zshrc`.

Each concern lives in its own file:

- Base shell behavior
- Aliases
- Path management
- Environment exports

This avoids long-term configuration entropy.

---

## 🛣 PATH Management

`30-paths.zsh` ensures:

- Homebrew tools are prioritized
- Works on Apple Silicon and Intel
- No hardcoded paths
- Prevents common PATH duplication issues
- Deterministic tool resolution

---

## 🔐 SSH Agent Strategy

This setup prefers the **1Password SSH Agent** when available.

Behavior:

- If 1Password agent socket exists → prefer it
- Otherwise → fallback to macOS launchd agent
- `doctor.sh --fix` can force the current session to use 1Password
- Agent socket discovery uses a bounded glob lookup (no recursive `find` scan), keeping doctor/install runs responsive.

No key generation. No key management. Only environment alignment.

---

## 🔐 Git Commit Signing (Optional)

The installer can optionally configure:

- `gpg.format = ssh`
- `commit.gpgsign = true`
- `user.signingkey` from your active SSH agent

This enables **SSH-based commit signing**, allowing GitHub to display:

> ✅ Verified

if your SSH key is added as a **Signing Key** in GitHub.

### Important

- The script does not create SSH keys.
- The script does not manage your SSH agent.
- You must manually add your SSH public key in:

GitHub → Settings → SSH and GPG Keys → New signing key

Safe by default with backups and explicit opt-in for optional Git setup.

---

## 🧪 Doctor Layer

`scripts/doctor.sh` validates your environment.

It checks:

- Bash version (>=4)
- Homebrew presence and prefix
- PATH hygiene and ordering
- Python origin
- VS Code CLI availability
- SSH agent state
- Git SSH signing configuration
- Optional repair actions with dry-run preview support

Run anytime:

```bash
~/.dotfiles/scripts/doctor.sh
```

Or:

```bash
~/.dotfiles/scripts/doctor.sh --fix
```

For CI/headless runs:

```bash
~/.dotfiles/scripts/doctor.sh --fix --non-interactive
```

For previewing repair actions without applying changes:

```bash
~/.dotfiles/scripts/doctor.sh --fix --dry-run --non-interactive
```

---

## 🔁 Installation Layer

`scripts/install.sh` makes the setup reproducible.

It:

- Ensures Bash 4+ (auto-bootstrap via Homebrew if needed)
- Backs up existing configs
- Creates symlinks
- Installs extensions
- Supports strict extension mode (`--strict-extensions`)
- Supports dry-run audit mode (`--dry-run`)
- Optionally configures SSH commit signing
- Supports deterministic signing key selection (`--signing-key`)
- Optionally configures Git identity (with CLI override support)
- Supports non-interactive automation and CI/headless usage
- Runs doctor automatically after installation
- Is safe to re-run

Idempotent by design.

---

# 🚀 Rebuild From Scratch (macOS)

This setup assumes a clean macOS environment.

---

## 1️⃣ Install VS Code

Download: https://code.visualstudio.com/

After installation:

Open VS Code → Cmd + Shift + P → Run:

Shell Command: Install 'code' command in PATH

Verify:

```bash
code --version
```

---

## 2️⃣ Install JetBrains Mono (Optional)

Download: https://www.jetbrains.com/lp/mono/

Install the font in macOS.

Restart VS Code after installation.

---

## 3️⃣ Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify:

```bash
brew --version
```

---

## 4️⃣ Install Python (Recommended)

```bash
brew install python
```

Verify:

```bash
python3 --version
```

---

## 5️⃣ Clone This Repository

```bash
git clone https://github.com/xndvaz/.dotfiles.git ~/.dotfiles
```

---

## 6️⃣ Run Installer

```bash
bash ~/.dotfiles/scripts/install.sh
```

During installation, you may be asked:

> Configure now? (Y/N)

If Git identity is missing, installer prompt mode can also ask for:

> Configure now? (Y/N)

If your clone is not in `~/.dotfiles`, run the installer from your clone path:

```bash
bash /absolute/path/to/your/clone/scripts/install.sh
```

For automated/bootstrap scripts, you can run non-interactively:

```bash
bash ~/.dotfiles/scripts/install.sh \
  --non-interactive \
  --strict-extensions \
  --configure-signing=no \
  --configure-identity=yes \
  --git-name "Your Name" \
  --git-email "you@example.com"
```

If stdin is not a TTY (for example in CI/pipelines), installer prompts are automatically disabled.
The same non-interactive behavior is propagated to the post-install doctor run.

For strict CI semantics, use `--configure-signing=yes` / `--configure-identity=yes`
to fail fast when required prerequisites are missing.

For an audit run that prints planned actions without modifying your machine:

```bash
bash ~/.dotfiles/scripts/install.sh \
  --dry-run \
  --non-interactive \
  --configure-signing=no \
  --configure-identity=no
```

If you need SSH signing in non-interactive mode and have multiple keys loaded:

```bash
bash ~/.dotfiles/scripts/install.sh \
  --non-interactive \
  --configure-signing=yes \
  --signing-key "ssh-ed25519 AAAA...YOUR_PUBLIC_KEY..."
```

After installation, the doctor runs automatically.

---

## 7️⃣ Validate With Doctor

```bash
bash ~/.dotfiles/scripts/doctor.sh --non-interactive
```

If your clone is elsewhere:

```bash
bash /absolute/path/to/your/clone/scripts/doctor.sh --non-interactive
```

---

## 8️⃣ Restart VS Code

Environment restored. Signed commits ready.

---

# ✅ Quality Gates

CI runs the following shell checks on each push/PR:

- `bash -n` for `install.sh`, `doctor.sh`, and `test-install-flags.sh`
- `shellcheck -x` for shell linting
- `shfmt -d` for formatting consistency
- `scripts/test-install-flags.sh` smoke matrix
- `scripts/doctor.sh --non-interactive` and `--fix --dry-run --non-interactive`

The workflow is defined in `.github/workflows/ci.yml`.

---

# 🏷 Releases and Changelog

Release history is tracked in `CHANGELOG.md`.

Recommended release flow:

1. Update `CHANGELOG.md` under `Unreleased`.
2. Cut an annotated tag from `main`:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Use semantic version tags (`vMAJOR.MINOR.PATCH`) for consistency.

---

# 🧭 Design Principles

This repository favors:

- Transparency over abstraction
- Explicit behavior over silent automation
- Portability over local hacks
- Stability over trend adoption

It is designed to age well.
