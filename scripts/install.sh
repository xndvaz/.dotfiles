#!/usr/bin/env bash

# =============================================================================
# Bootstrap: Ensure Bash 4+ on macOS
# -----------------------------------------------------------------------------
# macOS ships with Bash 3.2 (GPL licensing constraints).
# This repo uses Bash 4+ features (e.g. mapfile in signing flow).
#
# Strategy:
# - If current Bash version < 4:
#   - Require Homebrew
#   - Install modern Bash via Homebrew
#   - Re-exec this script using the new Bash binary
#
# Notes:
# - Does NOT replace /bin/bash.
# - Safe to re-run (idempotent).
# =============================================================================

if [[ -z "${BASH_VERSINFO[0]:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "[dotfiles] Bash 4+ required. Detected: ${BASH_VERSION:-unknown}. Bootstrapping..."

  if ! command -v brew >/dev/null 2>&1; then
    echo "[dotfiles] Homebrew not found. Please install Homebrew first, then re-run."
    exit 1
  fi

  brew install bash

  if [[ -x /opt/homebrew/bin/bash ]]; then
    NEW_BASH="/opt/homebrew/bin/bash"
  elif [[ -x /usr/local/bin/bash ]]; then
    NEW_BASH="/usr/local/bin/bash"
  else
    echo "[dotfiles] Homebrew Bash not found after installation."
    exit 1
  fi

  echo "[dotfiles] Re-executing with: $NEW_BASH"
  exec "$NEW_BASH" "$0" "$@"
fi

# =============================================================================
# Strict mode
# =============================================================================
set -euo pipefail

# =============================================================================
# install.sh
# -----------------------------------------------------------------------------
# Purpose:
#   Bootstrap this dotfiles repo on macOS:
#   - Link VS Code settings/keybindings from the repo into VS Code User folder.
#   - Install VS Code extensions listed in vscode/extensions.txt.
#   - Optionally configure Git SSH commit signing (GitHub Verified).
#   - Optionally configure Git identity (user.name, user.email).
#   - Run doctor at the end (and auto-fix SSH agent for this session if possible).
#
# Design goals:
# - Safe by default (backup existing targets before replacing)
# - Idempotent (safe to re-run)
# - Location-independent (can run from any working directory)
#
# Usage:
#   bash ~/.dotfiles/scripts/install.sh
#   # or (after chmod +x)
#   ~/.dotfiles/scripts/install.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve repo root regardless of current working directory
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "== Dotfiles install starting =="
echo "Repo root: $REPO_ROOT"

# -----------------------------------------------------------------------------
# VS Code paths (macOS Stable build)
# -----------------------------------------------------------------------------
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

REPO_VSCODE_DIR="$REPO_ROOT/vscode"
REPO_SETTINGS="$REPO_VSCODE_DIR/settings.json"
REPO_KEYBINDINGS="$REPO_VSCODE_DIR/keybindings.json"
REPO_EXTENSIONS_LIST="$REPO_VSCODE_DIR/extensions.txt"

VSCODE_SETTINGS="$VSCODE_USER_DIR/settings.json"
VSCODE_KEYBINDINGS="$VSCODE_USER_DIR/keybindings.json"

# -----------------------------------------------------------------------------
# Safety checks
# -----------------------------------------------------------------------------
if [[ ! -d "$REPO_VSCODE_DIR" ]]; then
  echo "Error: expected folder not found: $REPO_VSCODE_DIR" >&2
  exit 1
fi

if [[ ! -f "$REPO_SETTINGS" ]]; then
  echo "Error: expected file not found: $REPO_SETTINGS" >&2
  echo "Tip: create vscode/settings.json inside the repository." >&2
  exit 1
fi

mkdir -p "$VSCODE_USER_DIR"

# -----------------------------------------------------------------------------
# Utility: backup existing targets
# -----------------------------------------------------------------------------
backup_if_exists () {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local ts backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    mv "$target" "$backup"
    echo "Backed up: $target -> $backup"
  fi
}

# -----------------------------------------------------------------------------
# Utility: create symlink safely (idempotent)
# -----------------------------------------------------------------------------
link_file () {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    echo "Error: source does not exist: $source" >&2
    exit 1
  fi

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink "$target" || true)"
    if [[ "$current" == "$source" ]]; then
      echo "Already linked: $target -> $source"
      return 0
    fi
  fi

  backup_if_exists "$target"
  ln -sfn "$source" "$target"
  echo "Linked: $target -> $source"
}

have_cmd () { command -v "$1" >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# VS Code: install extensions listed in a file
# -----------------------------------------------------------------------------
install_extensions () {
  local list_file="$1"

  if [[ ! -f "$list_file" ]]; then
    echo "Notice: extensions list not found: $list_file"
    echo "Skipping VS Code extension install."
    return 0
  fi

  if ! have_cmd code; then
    echo "Notice: 'code' CLI not found in PATH."
    echo "Skipping VS Code extension install."
    echo "Tip: VS Code -> Command Palette -> Shell Command: Install 'code' command in PATH"
    return 0
  fi

  echo "Installing VS Code extensions from: $list_file"

  while IFS= read -r ext || [[ -n "$ext" ]]; do
    # Trim whitespace
    ext="${ext#"${ext%%[![:space:]]*}"}"
    ext="${ext%"${ext##*[![:space:]]}"}"

    # Skip empty/comment lines
    [[ -z "$ext" ]] && continue
    [[ "$ext" == \#* ]] && continue

    echo "  - $ext"
    code --install-extension "$ext" >/dev/null 2>&1 || {
      echo "    (warn) failed to install: $ext" >&2
    }
  done < "$list_file"

  echo "Extensions install step done."
}

# -----------------------------------------------------------------------------
# Optional: Git SSH commit signing
# -----------------------------------------------------------------------------
configure_git_ssh_signing () {
  echo ""
  echo "== Optional: Git SSH commit signing =="

  if ! have_cmd git; then
    echo "Notice: git not found. Skipping signing setup."
    return 0
  fi

  local current_format current_gpgsign current_signingkey
  current_format="$(git config --global --get gpg.format || true)"
  current_gpgsign="$(git config --global --get commit.gpgsign || true)"
  current_signingkey="$(git config --global --get user.signingkey || true)"

  if [[ "$current_format" == "ssh" && "$current_gpgsign" == "true" && -n "$current_signingkey" ]]; then
    echo "Already configured: gpg.format=ssh, commit.gpgsign=true."
    return 0
  fi

  echo "This enables signed commits using your SSH agent (GitHub can show Verified)."
  echo "Configure now? (Y/N)"
  read -r ANSWER

  if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Skipped Git signing configuration."
    return 0
  fi

  if ! have_cmd ssh-add; then
    echo "❌ ssh-add not found."
    echo "Tip: On macOS it should exist. If not, install Xcode Command Line Tools."
    return 1
  fi

  git config --global gpg.format ssh
  git config --global commit.gpgsign true

  # Collect ed25519 keys from the agent.
  mapfile -t KEY_LINES < <(ssh-add -L 2>/dev/null | awk '$1=="ssh-ed25519"{print}')

  if [[ "${#KEY_LINES[@]}" -eq 0 ]]; then
    echo "❌ No ssh-ed25519 keys found in your SSH agent."
    echo "Tip: If you use 1Password: enable SSH Agent and add/authorize the key."
    return 1
  fi

  if [[ "${#KEY_LINES[@]}" -eq 1 ]]; then
    local k
    k="$(echo "${KEY_LINES[0]}" | awk '{print $1" "$2}')"
    git config --global user.signingkey "$k"
    echo "✅ SSH commit signing configured (single key)."
    echo "Signing key: $(git config --global --get user.signingkey)"
    return 0
  fi

  echo "Multiple ssh-ed25519 keys found in your SSH agent:"
  echo ""

  local i line algo pub comment display
  for i in "${!KEY_LINES[@]}"; do
    line="${KEY_LINES[$i]}"
    algo="$(echo "$line" | awk '{print $1}')"
    pub="$(echo "$line" | awk '{print $2}')"
    comment="$(echo "$line" | cut -d' ' -f3- || true)"
    if [[ -n "$comment" ]]; then
      display="$algo $pub  ($comment)"
    else
      display="$algo $pub"
    fi
    printf "  [%d] %s\n" "$((i+1))" "$display"
  done

  echo ""
  read -r -p "Choose a key number to use for signing (Enter to cancel): " CHOICE

  if [[ -z "${CHOICE}" ]]; then
    echo "Cancelled. SSH signing not configured."
    return 0
  fi

  if ! [[ "${CHOICE}" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#KEY_LINES[@]} )); then
    echo "❌ Invalid selection."
    return 1
  fi

  line="${KEY_LINES[$((CHOICE-1))]}"
  algo="$(echo "$line" | awk '{print $1}')"
  pub="$(echo "$line" | awk '{print $2}')"
  git config --global user.signingkey "$algo $pub"

  echo "✅ SSH commit signing configured (selected key)."
  echo "Signing key: $(git config --global --get user.signingkey)"
}

# -----------------------------------------------------------------------------
# Optional: Git user identity (user.name, user.email)
# -----------------------------------------------------------------------------
configure_git_identity () {
  echo ""
  echo "== Optional: Git user identity =="

  if ! have_cmd git; then
    echo "Notice: git not found. Skipping identity setup."
    return 0
  fi

  local current_name current_email
  current_name="$(git config --global --get user.name || true)"
  current_email="$(git config --global --get user.email || true)"

  if [[ -n "$current_name" && -n "$current_email" ]]; then
    echo "Already configured:"
    echo "  user.name  = $current_name"
    echo "  user.email = $current_email"
    return 0
  fi

  echo "Git global identity is not fully configured."
  echo "Configure now? (Y/N)"
  read -r ANSWER

  if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Skipped Git identity configuration."
    return 0
  fi

  local new_name new_email
  read -r -p "Enter Git user.name: " new_name
  read -r -p "Enter Git user.email: " new_email

  if [[ -z "$new_name" || -z "$new_email" ]]; then
    echo "Invalid input. Aborting identity setup."
    return 1
  fi

  git config --global user.name "$new_name"
  git config --global user.email "$new_email"

  echo "Git identity configured."
}

# -----------------------------------------------------------------------------
# Execution: VS Code links
# -----------------------------------------------------------------------------
link_file "$REPO_SETTINGS" "$VSCODE_SETTINGS"

# Keybindings: ensure a valid JSON file exists in the repo.
if [[ ! -f "$REPO_KEYBINDINGS" ]]; then
  mkdir -p "$REPO_VSCODE_DIR"
  printf '%s\n' '[]' > "$REPO_KEYBINDINGS"
  echo "Created: $REPO_KEYBINDINGS"
fi
link_file "$REPO_KEYBINDINGS" "$VSCODE_KEYBINDINGS"

# -----------------------------------------------------------------------------
# VS Code: extensions
# -----------------------------------------------------------------------------
install_extensions "$REPO_EXTENSIONS_LIST"

# -----------------------------------------------------------------------------
# Optional: Git steps (macOS-only)
# -----------------------------------------------------------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  configure_git_ssh_signing
  configure_git_identity
else
  echo "Notice: Git setup is macOS-only in this script. Skipping."
fi

# -----------------------------------------------------------------------------
# Post-install: run doctor (non-fatal)
# -----------------------------------------------------------------------------
DOCTOR_SCRIPT="$REPO_ROOT/scripts/doctor.sh"

echo ""
echo "== Post-install: dotfiles doctor =="

if [[ -f "$DOCTOR_SCRIPT" ]]; then
  # Detect 1Password SSH agent socket.
  # With `set -euo pipefail`, a failing `find` pipeline can abort the script.
  # Make this detection explicitly non-fatal with `|| true`.
  OP_SSH_SOCK="$(
    find "$HOME/Library/Group Containers" -maxdepth 4 -type s -name "agent.sock" \
      -path "*com.1password*/t/agent.sock" -print 2>/dev/null | head -n 1 || true
  )"

  if [[ -n "${OP_SSH_SOCK:-}" && -S "$OP_SSH_SOCK" ]]; then
    echo "Notice: 1Password SSH agent detected. Running doctor with --fix for this session."
    bash "$DOCTOR_SCRIPT" --fix || echo "Notice: doctor reported issues (non-fatal)."
  else
    bash "$DOCTOR_SCRIPT" || echo "Notice: doctor reported issues (non-fatal)."
  fi
else
  echo "Notice: doctor script not found: $DOCTOR_SCRIPT"
  echo "Tip: chmod +x $DOCTOR_SCRIPT"
fi

echo ""
echo "== Done =="
echo "Tip: Restart VS Code after theme/icon changes."