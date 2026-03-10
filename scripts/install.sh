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
#   - Link ~/.zshrc to the repo bootstrap loader.
#   - Link VS Code settings/keybindings from the repo into VS Code User folder.
#   - Install VS Code extensions listed in vscode/extensions.txt.
#   - Configure Git editor for blocking interactive operations.
#   - Configure Git commit template from this repo.
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
#
# Automation options:
#   --non-interactive
#   --strict-extensions
#   --configure-signing=<yes|no|prompt>
#   --configure-identity=<yes|no|prompt>
#   --signing-key="<algo pubkey>"
#   --git-name="<name>"
#   --git-email="<email>"
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve repo root regardless of current working directory
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

NON_INTERACTIVE=0
STRICT_EXTENSIONS=0
CONFIGURE_SIGNING="prompt"
CONFIGURE_IDENTITY="prompt"
CLI_SIGNING_KEY=""
CLI_GIT_NAME=""
CLI_GIT_EMAIL=""

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --non-interactive                  Disable prompts for optional setup.
  --strict-extensions                Fail install if extensions cannot be installed.
  --configure-signing=<mode>         Mode for Git SSH signing: yes|no|prompt.
  --configure-identity=<mode>        Mode for Git identity: yes|no|prompt.
  --signing-key="<algo pubkey>"      Signing key (first two SSH fields).
  --git-name="<name>"                Git user.name value for identity setup.
  --git-email="<email>"              Git user.email value for identity setup.
  -h, --help                         Show this help.
EOF
}

normalize_mode() {
  case "$1" in
    yes|no|prompt) echo "$1" ;;
    y|Y|true|TRUE|1) echo "yes" ;;
    n|N|false|FALSE|0) echo "no" ;;
    *) return 1 ;;
  esac
}

parse_args() {
  local mode

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_usage
        exit 0
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        ;;
      --strict-extensions)
        STRICT_EXTENSIONS=1
        ;;
      --configure-signing=*)
        mode="${1#*=}"
        if ! mode="$(normalize_mode "$mode")"; then
          echo "Error: invalid value for --configure-signing: ${1#*=}" >&2
          exit 1
        fi
        CONFIGURE_SIGNING="$mode"
        ;;
      --configure-signing)
        shift
        if [[ "$#" -eq 0 ]]; then
          echo "Error: --configure-signing requires a value" >&2
          exit 1
        fi
        if ! mode="$(normalize_mode "$1")"; then
          echo "Error: invalid value for --configure-signing: $1" >&2
          exit 1
        fi
        CONFIGURE_SIGNING="$mode"
        ;;
      --configure-identity=*)
        mode="${1#*=}"
        if ! mode="$(normalize_mode "$mode")"; then
          echo "Error: invalid value for --configure-identity: ${1#*=}" >&2
          exit 1
        fi
        CONFIGURE_IDENTITY="$mode"
        ;;
      --configure-identity)
        shift
        if [[ "$#" -eq 0 ]]; then
          echo "Error: --configure-identity requires a value" >&2
          exit 1
        fi
        if ! mode="$(normalize_mode "$1")"; then
          echo "Error: invalid value for --configure-identity: $1" >&2
          exit 1
        fi
        CONFIGURE_IDENTITY="$mode"
        ;;
      --signing-key=*)
        CLI_SIGNING_KEY="${1#*=}"
        ;;
      --signing-key)
        shift
        if [[ "$#" -eq 0 ]]; then
          echo "Error: --signing-key requires a value" >&2
          exit 1
        fi
        CLI_SIGNING_KEY="$1"
        ;;
      --git-name=*)
        CLI_GIT_NAME="${1#*=}"
        ;;
      --git-name)
        shift
        if [[ "$#" -eq 0 ]]; then
          echo "Error: --git-name requires a value" >&2
          exit 1
        fi
        CLI_GIT_NAME="$1"
        ;;
      --git-email=*)
        CLI_GIT_EMAIL="${1#*=}"
        ;;
      --git-email)
        shift
        if [[ "$#" -eq 0 ]]; then
          echo "Error: --git-email requires a value" >&2
          exit 1
        fi
        CLI_GIT_EMAIL="$1"
        ;;
      *)
        echo "Error: unknown argument: $1" >&2
        print_usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

parse_args "$@"

if [[ -n "$CLI_SIGNING_KEY" ]]; then
  read -r key_algo key_pub key_rest <<< "$CLI_SIGNING_KEY"
  if [[ -z "${key_algo:-}" || -z "${key_pub:-}" ]]; then
    echo "Error: invalid --signing-key format. Expected: '<algo> <pubkey>'" >&2
    exit 1
  fi
  CLI_SIGNING_KEY="$key_algo $key_pub"
  unset key_algo key_pub key_rest

  if [[ "$CONFIGURE_SIGNING" == "no" ]]; then
    echo "Error: --signing-key cannot be used with --configure-signing=no" >&2
    exit 1
  fi

  CONFIGURE_SIGNING="yes"
fi

if [[ "$CONFIGURE_IDENTITY" == "no" && ( -n "$CLI_GIT_NAME" || -n "$CLI_GIT_EMAIL" ) ]]; then
  echo "Error: --git-name/--git-email cannot be used with --configure-identity=no" >&2
  exit 1
fi

if [[ "$NON_INTERACTIVE" -eq 0 && ! -t 0 ]]; then
  NON_INTERACTIVE=1
  echo "Notice: stdin is not a TTY. Enabling non-interactive mode."
fi

echo "== Dotfiles install starting =="
echo "Repo root: $REPO_ROOT"

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

REPO_VSCODE_DIR="$REPO_ROOT/vscode"
REPO_SETTINGS="$REPO_VSCODE_DIR/settings.json"
REPO_KEYBINDINGS="$REPO_VSCODE_DIR/keybindings.json"
REPO_EXTENSIONS_LIST="$REPO_VSCODE_DIR/extensions.txt"

VSCODE_SETTINGS="$VSCODE_USER_DIR/settings.json"
VSCODE_KEYBINDINGS="$VSCODE_USER_DIR/keybindings.json"

REPO_ZSH_BOOTSTRAP="$REPO_ROOT/zshrc.bootstrap"
REPO_GIT_COMMIT_TEMPLATE="$REPO_ROOT/git/commit-template"

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
# Zsh: bootstrap ~/.zshrc from repo
# -----------------------------------------------------------------------------
ensure_zsh_bootstrap () {
  local user_zshrc="$HOME/.zshrc"

  if [[ ! -f "$REPO_ZSH_BOOTSTRAP" ]]; then
    echo "Error: expected file not found: $REPO_ZSH_BOOTSTRAP" >&2
    exit 1
  fi

  link_file "$REPO_ZSH_BOOTSTRAP" "$user_zshrc"
}

# -----------------------------------------------------------------------------
# VS Code: install extensions listed in a file
# -----------------------------------------------------------------------------
install_extensions () {
  local list_file="$1"
  local installed_ext
  local installed_ext_norm
  local ext_norm
  local ext_failures=0
  local -a installed_list=()
  local -A installed_set=()

  if [[ ! -f "$list_file" ]]; then
    echo "Notice: extensions list not found: $list_file"
    echo "Skipping VS Code extension install."
    return 0
  fi

  if ! have_cmd code; then
    echo "Notice: 'code' CLI not found in PATH."
    echo "Skipping VS Code extension install."
    echo "Tip: VS Code -> Command Palette -> Shell Command: Install 'code' command in PATH"
    if [[ "$STRICT_EXTENSIONS" -eq 1 ]]; then
      echo "Error: --strict-extensions is enabled and 'code' CLI is unavailable." >&2
      return 1
    fi
    return 0
  fi

  echo "Installing VS Code extensions from: $list_file"
  mapfile -t installed_list < <(code --list-extensions 2>/dev/null || true)
  for installed_ext in "${installed_list[@]}"; do
    [[ -n "$installed_ext" ]] || continue
    installed_ext_norm="${installed_ext,,}"
    installed_set["$installed_ext_norm"]=1
  done

  while IFS= read -r ext || [[ -n "$ext" ]]; do
    ext="${ext#"${ext%%[![:space:]]*}"}"
    ext="${ext%"${ext##*[![:space:]]}"}"

    [[ -z "$ext" ]] && continue
    [[ "$ext" == \#* ]] && continue

    ext_norm="${ext,,}"

    if [[ -n "${installed_set["$ext_norm"]:-}" ]]; then
      echo "  - $ext (already installed)"
      continue
    fi

    echo "  - $ext"
    if code --install-extension "$ext" >/dev/null 2>&1; then
      installed_set["$ext_norm"]=1
    else
      echo "    (warn) failed to install: $ext" >&2
      ext_failures=$((ext_failures + 1))
    fi
  done < "$list_file"

  if [[ "$ext_failures" -gt 0 && "$STRICT_EXTENSIONS" -eq 1 ]]; then
    echo "Error: failed to install $ext_failures extension(s) with --strict-extensions enabled." >&2
    return 1
  fi

  echo "Extensions install step done."
}

# -----------------------------------------------------------------------------
# Git: editor for interactive operations
# -----------------------------------------------------------------------------
configure_git_editor () {
  echo ""
  echo "== Git editor =="

  if ! have_cmd git; then
    echo "Notice: git not found. Skipping editor setup."
    return 0
  fi

  if ! have_cmd code; then
    echo "Notice: 'code' CLI not found in PATH."
    echo "Skipping Git editor setup."
    return 0
  fi

  local desired current
  desired="code --wait"
  current="$(git config --global --get core.editor || true)"

  if [[ "$current" == "$desired" ]]; then
    echo "Already configured: core.editor=$desired"
    return 0
  fi

  git config --global core.editor "$desired"
  echo "Configured: core.editor=$desired"
}

# -----------------------------------------------------------------------------
# Git: commit template from repo
# -----------------------------------------------------------------------------
configure_git_commit_template () {
  echo ""
  echo "== Git commit template =="

  if ! have_cmd git; then
    echo "Notice: git not found. Skipping commit template setup."
    return 0
  fi

  if [[ ! -f "$REPO_GIT_COMMIT_TEMPLATE" ]]; then
    echo "Notice: commit template not found: $REPO_GIT_COMMIT_TEMPLATE"
    echo "Skipping commit template setup."
    return 0
  fi

  local desired current
  desired="$REPO_GIT_COMMIT_TEMPLATE"
  current="$(git config --global --get commit.template || true)"

  if [[ "$current" == "$desired" ]]; then
    echo "Already configured: commit.template=$desired"
    return 0
  fi

  git config --global commit.template "$desired"
  echo "Configured: commit.template=$desired"
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
    if [[ -n "$CLI_SIGNING_KEY" && "$current_signingkey" != "$CLI_SIGNING_KEY" ]]; then
      echo "Notice: current signing key differs from --signing-key. Updating signing key."
    else
      echo "Already configured: gpg.format=ssh, commit.gpgsign=true."
      return 0
    fi
  fi

  local signing_required=0
  if [[ "$CONFIGURE_SIGNING" == "yes" ]]; then
    signing_required=1
  fi

  if [[ "$CONFIGURE_SIGNING" == "no" ]]; then
    echo "Skipped Git signing configuration (--configure-signing=no)."
    return 0
  fi

  if [[ "$CONFIGURE_SIGNING" == "prompt" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      echo "Notice: non-interactive mode enabled. Skipping signing setup."
      return 0
    fi

    echo "This enables signed commits using your SSH agent (GitHub can show Verified)."
    echo "Configure now? (Y/N)"
    read -r ANSWER

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
      echo "Skipped Git signing configuration."
      return 0
    fi
  fi

  if ! have_cmd ssh-add; then
    echo "Notice: ssh-add not found. Skipping signing setup."
    echo "Tip: On macOS it should exist. If not, install Xcode Command Line Tools."
    if [[ "$signing_required" -eq 1 ]]; then
      echo "Error: signing was explicitly required but ssh-add is unavailable." >&2
      return 1
    fi
    return 0
  fi

  local -a KEY_LINES
  local selected_key
  selected_key=""

  mapfile -t KEY_LINES < <(ssh-add -L 2>/dev/null | awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print}')

  if [[ "${#KEY_LINES[@]}" -eq 0 ]]; then
    echo "Notice: no compatible SSH keys found in your SSH agent. Skipping signing setup."
    echo "Tip: If you use 1Password: enable SSH Agent and add/authorize the key."
    if [[ "$signing_required" -eq 1 ]]; then
      echo "Error: signing was explicitly required but no compatible SSH keys were found." >&2
      return 1
    fi
    return 0
  fi

  if [[ -n "$CLI_SIGNING_KEY" ]]; then
    local key_found=0
    local line_key

    for line_key in "${KEY_LINES[@]}"; do
      if [[ "$(echo "$line_key" | awk '{print $1" "$2}')" == "$CLI_SIGNING_KEY" ]]; then
        selected_key="$CLI_SIGNING_KEY"
        key_found=1
        break
      fi
    done

    if [[ "$key_found" -eq 0 ]]; then
      echo "Notice: provided --signing-key not found in SSH agent. Skipping signing setup."
      if [[ "$signing_required" -eq 1 ]]; then
        echo "Error: signing was explicitly required but the provided key is unavailable." >&2
        return 1
      fi
      return 0
    fi
  elif [[ "${#KEY_LINES[@]}" -eq 1 ]]; then
    selected_key="$(echo "${KEY_LINES[0]}" | awk '{print $1" "$2}')"
  else
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      echo "Notice: multiple SSH keys found and non-interactive mode is enabled."
      echo "Skipping Git signing configuration."
      if [[ "$signing_required" -eq 1 ]]; then
        echo "Error: signing was explicitly required but key selection needs interaction." >&2
        return 1
      fi
      return 0
    fi

    echo "Multiple SSH keys found in your SSH agent:"
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
      if [[ "$signing_required" -eq 1 ]]; then
        echo "Error: signing was explicitly required but key selection was cancelled." >&2
        return 1
      fi
      return 0
    fi

    if ! [[ "${CHOICE}" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#KEY_LINES[@]} )); then
      echo "Notice: invalid selection. Skipping signing setup."
      if [[ "$signing_required" -eq 1 ]]; then
        echo "Error: signing was explicitly required but key selection was invalid." >&2
        return 1
      fi
      return 0
    fi

    line="${KEY_LINES[$((CHOICE-1))]}"
    algo="$(echo "$line" | awk '{print $1}')"
    pub="$(echo "$line" | awk '{print $2}')"
    selected_key="$algo $pub"
  fi

  git config --global gpg.format ssh
  git config --global commit.gpgsign true
  git config --global user.signingkey "$selected_key"

  echo "✅ SSH commit signing configured."
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

  local identity_required=0
  local cli_identity_provided=0
  if [[ "$CONFIGURE_IDENTITY" == "yes" ]]; then
    identity_required=1
  fi
  if [[ -n "$CLI_GIT_NAME" || -n "$CLI_GIT_EMAIL" ]]; then
    cli_identity_provided=1
  fi

  if [[ "$CONFIGURE_IDENTITY" == "no" ]]; then
    echo "Skipped Git identity configuration (--configure-identity=no)."
    return 0
  fi

  if [[ "$cli_identity_provided" -eq 1 ]]; then
    if [[ -z "$CLI_GIT_NAME" || -z "$CLI_GIT_EMAIL" ]]; then
      echo "Notice: both --git-name and --git-email are required. Skipping identity setup."
      if [[ "$identity_required" -eq 1 ]]; then
        echo "Error: identity was explicitly required but git name/email are incomplete." >&2
        return 1
      fi
      return 0
    fi

    if [[ "$current_name" == "$CLI_GIT_NAME" && "$current_email" == "$CLI_GIT_EMAIL" ]]; then
      echo "Already configured:"
      echo "  user.name  = $current_name"
      echo "  user.email = $current_email"
      return 0
    fi

    git config --global user.name "$CLI_GIT_NAME"
    git config --global user.email "$CLI_GIT_EMAIL"
    echo "Git identity configured."
    return 0
  fi

  if [[ -n "$current_name" && -n "$current_email" ]]; then
    echo "Already configured:"
    echo "  user.name  = $current_name"
    echo "  user.email = $current_email"
    return 0
  fi

  if [[ "$CONFIGURE_IDENTITY" == "prompt" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      echo "Notice: non-interactive mode enabled. Skipping identity setup."
      return 0
    fi

    echo "Git global identity is not fully configured."
    echo "Configure now? (Y/N)"
    read -r ANSWER

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
      echo "Skipped Git identity configuration."
      return 0
    fi
  fi

  local new_name new_email
  new_name="$CLI_GIT_NAME"
  new_email="$CLI_GIT_EMAIL"

  if [[ -n "$new_name" || -n "$new_email" ]]; then
    if [[ -z "$new_name" || -z "$new_email" ]]; then
      echo "Notice: both --git-name and --git-email are required. Skipping identity setup."
      if [[ "$identity_required" -eq 1 ]]; then
        echo "Error: identity was explicitly required but git name/email are incomplete." >&2
        return 1
      fi
      return 0
    fi
  elif [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    echo "Notice: non-interactive identity setup requires --git-name and --git-email."
    echo "Skipping Git identity configuration."
    if [[ "$identity_required" -eq 1 ]]; then
      echo "Error: identity was explicitly required in non-interactive mode." >&2
      return 1
    fi
    return 0
  else
    read -r -p "Enter Git user.name: " new_name
    read -r -p "Enter Git user.email: " new_email
  fi

  if [[ -z "$new_name" || -z "$new_email" ]]; then
    echo "Notice: invalid identity input. Skipping identity setup."
    if [[ "$identity_required" -eq 1 ]]; then
      echo "Error: identity was explicitly required but input was invalid." >&2
      return 1
    fi
    return 0
  fi

  git config --global user.name "$new_name"
  git config --global user.email "$new_email"

  echo "Git identity configured."
}

# -----------------------------------------------------------------------------
# Execution: Zsh bootstrap
# -----------------------------------------------------------------------------
ensure_zsh_bootstrap

# -----------------------------------------------------------------------------
# Execution: VS Code links
# -----------------------------------------------------------------------------
link_file "$REPO_SETTINGS" "$VSCODE_SETTINGS"

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
  configure_git_editor
  configure_git_commit_template
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
