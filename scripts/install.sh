#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install.sh
# -----------------------------------------------------------------------------
# Purpose:
#   Bootstrap this dotfiles repo on macOS:
#   - Link VS Code settings/keybindings from the repo into the expected VS Code
#     user directory using symlinks (so repo changes reflect instantly).
#   - Install VS Code extensions listed in vscode/extensions.txt.
#   - Optionally configure Git SSH commit signing (for GitHub Verified badge).
#
# Design goals:
#   - Safe by default: backs up any existing target file/dir before replacing.
#   - Idempotent: re-running should not break anything (and avoids noisy backups
#     when links are already correct).
#   - Location-independent: can be executed from ANY working directory.
#
# Usage:
#   bash ~/.dotfiles/scripts/install.sh
#   # or (after chmod +x)
#   ~/.dotfiles/scripts/install.sh
# =============================================================================

# --- Resolve repo root no matter where you run this script from ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "== Dotfiles install starting =="
echo "Repo root: $REPO_ROOT"

# --- macOS VS Code (Stable) user folder ---
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

# --- Repo paths ---
REPO_VSCODE_DIR="$REPO_ROOT/vscode"
REPO_SETTINGS="$REPO_VSCODE_DIR/settings.json"
REPO_KEYBINDINGS="$REPO_VSCODE_DIR/keybindings.json"
REPO_EXTENSIONS_LIST="$REPO_VSCODE_DIR/extensions.txt"

# --- Targets in the system ---
VSCODE_SETTINGS="$VSCODE_USER_DIR/settings.json"
VSCODE_KEYBINDINGS="$VSCODE_USER_DIR/keybindings.json"

# --- Safety checks (fail fast with clear message) ---
if [[ ! -d "$REPO_VSCODE_DIR" ]]; then
  echo "Error: expected folder not found: $REPO_VSCODE_DIR" >&2
  exit 1
fi

if [[ ! -f "$REPO_SETTINGS" ]]; then
  echo "Error: expected file not found: $REPO_SETTINGS" >&2
  echo "Tip: create vscode/settings.json inside the repo." >&2
  exit 1
fi

mkdir -p "$VSCODE_USER_DIR"

backup_if_exists () {
  # Backup any existing file/dir/symlink at the target path.
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local ts backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    mv "$target" "$backup"
    echo "Backed up: $target -> $backup"
  fi
}

link_file () {
  # Create a symlink from target -> source (source is in the repo).
  # If the target already points to the same source, do nothing.
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    echo "Error: source does not exist: $source" >&2
    exit 1
  fi

  # If already linked correctly, skip.
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

have_cmd () {
  command -v "$1" >/dev/null 2>&1
}

install_extensions () {
  # Install extensions listed one per line, ignoring:
  # - empty lines
  # - comments starting with #
  local list_file="$1"

  if [[ ! -f "$list_file" ]]; then
    echo "Notice: extensions list not found: $list_file"
    echo "Skipping VS Code extension install."
    return 0
  fi

  if ! have_cmd code; then
    echo "Notice: 'code' CLI not found in PATH."
    echo "Skipping VS Code extension install."
    echo "Tip: VS Code -> Command Palette -> 'Shell Command: Install 'code' command in PATH'"
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

configure_git_ssh_signing () {
  # macOS-only helper. Configures Git to sign commits with SSH keys (gpg.format=ssh)
  # so GitHub can show "Verified" for commit signatures (when key is added as Signing Key).
  #
  # Behavior:
  # - If already configured: do nothing.
  # - Otherwise: ask (y|N). If user says yes:
  #   - Ensure gpg.format=ssh and commit.gpgsign=true
  #   - Choose signing key from ssh-agent (supports multiple keys)
  #
  # NOTE: This does NOT manage your SSH agent or keys. It only sets git config.

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
    echo "Already configured: gpg.format=ssh, commit.gpgsign=true, user.signingkey set."
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
    echo "❌ ssh-add not found. Skipping."
    echo "Tip: On macOS it should exist. If not, install Xcode Command Line Tools."
    return 1
  fi

  # Ensure SSH signing is enabled globally
  git config --global gpg.format ssh
  git config --global commit.gpgsign true

  # Collect keys from agent.
  # We want: algo, base64, comment (if exists) -> show user-friendly list.
  # Format from ssh-add -L:
  #   ssh-ed25519 AAAAC3... comment
  # comment may be absent, so we handle both.
  mapfile -t KEY_LINES < <(ssh-add -L 2>/dev/null | awk '$1=="ssh-ed25519"{print}')

  if [[ "${#KEY_LINES[@]}" -eq 0 ]]; then
    echo "❌ No ssh-ed25519 keys found in your SSH agent."
    echo "Tip: If you use 1Password: enable SSH Agent and add/authorize the key."
    return 1
  fi

  if [[ "${#KEY_LINES[@]}" -eq 1 ]]; then
    # Git expects "ssh-ed25519 <base64>" (no comment required)
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
    # comment may contain spaces; grab everything after field 2
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
# VS Code: settings.json
# -----------------------------------------------------------------------------
link_file "$REPO_SETTINGS" "$VSCODE_SETTINGS"

# -----------------------------------------------------------------------------
# VS Code: keybindings.json
# -----------------------------------------------------------------------------
# If repo doesn't have it yet, create a minimal valid JSON file (NO comments).
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
# Optional: Git SSH signing (macOS-only)
# -----------------------------------------------------------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  configure_git_ssh_signing
else
  echo "Notice: Git SSH signing setup is macOS-only in this script. Skipping."
fi

echo ""
echo "== Done =="
echo "Tip: Restart VS Code after theme/icon changes."