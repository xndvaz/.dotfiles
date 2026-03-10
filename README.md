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
├── scripts/          → Installation orchestration
│   ├── install.sh    → Bootstrap + environment provisioning
│   └── doctor.sh     → Environment diagnostics & validation
├── shell/            → Modular ZSH configuration
│   ├── 10-base.zsh   → Core shell behavior
│   ├── 20-exports.zsh → Environment variables & SSH agent preference
│   ├── 30-paths.zsh  → Homebrew-aware PATH management
│   └── 40-aliases.zsh → Command shortcuts
├── vscode/           → VS Code configuration
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt
├── .editorconfig     → Cross-tool formatting baseline
├── .prettierrc       → Explicit formatting rules
├── .prettierignore
└── zshrc.bootstrap   → Minimal shell loader
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

---

## 🔁 Installation Layer

`scripts/install.sh` makes the setup reproducible.

It:

- Ensures Bash 4+ (auto-bootstrap via Homebrew if needed)
- Backs up existing configs
- Creates symlinks
- Installs extensions
- Supports strict extension mode (`--strict-extensions`)
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

## 2️⃣ Install JetBrains Mono

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

## 4️⃣ Install Python

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

> Do you want to configure SSH commit signing? (y/N)

If Git identity is missing, installer prompt mode can also ask for:

> Do you want to configure Git user.name / user.email? (y/N)

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

For strict CI semantics, use `--configure-signing=yes` / `--configure-identity=yes`
to fail fast when required prerequisites are missing.

If you need SSH signing in non-interactive mode and have multiple keys loaded:

```bash
bash ~/.dotfiles/scripts/install.sh \
  --non-interactive \
  --configure-signing=yes \
  --signing-key "ssh-ed25519 AAAA...YOUR_PUBLIC_KEY..."
```

After installation, the doctor runs automatically.

---

## 7️⃣ Restart VS Code

Environment restored. Signed commits ready.

---

# 🧭 Design Principles

This repository favors:

- Transparency over abstraction
- Explicit behavior over silent automation
- Portability over local hacks
- Stability over trend adoption

It is designed to age well.
