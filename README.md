# 🛠 xndvaz/.dotfiles

> A layered, reproducible macOS development foundation.

This repository contains a modular VS Code + ZSH setup designed for\
clarity, consistency, and long-term maintainability.

No hidden automation.\
No black-box scripts.\
No machine-specific hacks.

Just explicit, readable infrastructure.

---

# 🧠 Philosophy

Your environment shapes how you think.

This setup is built around:

- 🧱 Structure over improvisation\
- 🎯 Explicit formatting rules\
- 🧩 Modular shell architecture\
- 🔁 Reproducibility across machines\
- 🔐 Signed commits by default (optional bootstrap)\
- 🧼 Minimalism without fragility

Everything is readable.\
Everything is intentional.

---

# 📌 Who This Is For

This setup can be useful if you:

- Want a clean starting point for macOS development\
- Prefer explicit configuration over automation magic\
- Care about formatting consistency\
- Like modular shell architecture\
- Want something reproducible across machines\
- Want GitHub "Verified" commit signatures using SSH

You can use it as-is, fork it, or adapt parts of it.

It's a foundation --- not a rigid framework.

---

# 🏗 Architecture

```text
~/.dotfiles
├── scripts/          → Installation orchestration
│   └── install.sh
├── shell/            → Modular ZSH configuration
│   ├── base.zsh
│   ├── aliases.zsh
│   ├── paths.zsh
│   └── exports.zsh
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

- Explicit default formatters\
- Controlled Prettier behavior (`requireConfig`)\
- Stable visual rules (ruler, whitespace, cursor behavior)\
- Minimal noise, predictable output

---

## 🐚 Shell Layer

ZSH configuration is modular --- not a monolithic `.zshrc`.

Each concern lives in its own file:

- Base shell behavior\
- Aliases\
- Path management\
- Environment exports

This avoids long-term configuration entropy.

---

## 📏 Formatting Layer

Formatting is explicit and project-aware.

- Prettier runs only when a project defines it.\
- Black formats Python.\
- JSON uses VS Code's native formatter.\
- `.editorconfig` enforces cross-tool consistency.

No implicit formatting surprises.

---

## 🔐 Git Commit Signing (Optional)

The installer can optionally configure:

- `gpg.format = ssh`\
- `commit.gpgsign = true`\
- `user.signingkey` from your active SSH agent

This enables **SSH-based commit signing**, allowing GitHub to display:

> ✅ Verified

if your SSH key is added as a **Signing Key** in GitHub.

### Important

- The script does not create SSH keys.\
- The script does not manage your SSH agent.\
- You must manually add your SSH public key in:

GitHub → Settings → SSH and GPG Keys → New signing key

The setup supports multiple SSH keys and lets you choose interactively.

Safe by default. No overwrite without confirmation.

---

## 🔁 Installation Layer

`scripts/install.sh` makes the setup reproducible.

It:

- Backs up existing configs\
- Creates symlinks\
- Installs extensions\
- Optionally configures SSH commit signing\
- Is safe to re-run

Idempotent by design.

---

# 🚀 Rebuild From Scratch (macOS)

This setup assumes a clean macOS environment.

---

## 1️⃣ Install VS Code

Download:\
https://code.visualstudio.com/

After installation:

Open VS Code →\
Cmd + Shift + P →\
Run:

Shell Command: Install 'code' command in PATH

Verify:

```bash
code --version
```

---

## 2️⃣ Install JetBrains Mono

Download:\
https://www.jetbrains.com/lp/mono/

Install the font in macOS.

Restart VS Code after installation.

---

## 3️⃣ Install Homebrew

```bash
/ bin / bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

If you answer **yes**, the script will:

- Detect available SSH keys from your agent\
- Let you choose one (if multiple exist)\
- Configure Git for SSH commit signing

---

## 7️⃣ Restart VS Code

Environment restored.

Signed commits ready.

---

# 🧭 Design Principles

This repository favors:

- Transparency over abstraction\
- Explicit behavior over silent automation\
- Portability over local hacks\
- Stability over trend adoption

It is designed to age well.
