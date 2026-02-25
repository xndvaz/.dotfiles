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

echo "== Done =="
echo "Tip: Restart VS Code after theme/icon changes."