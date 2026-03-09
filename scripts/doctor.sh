#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# dotfiles doctor
#
# Diagnostics + repair tool for workstation bootstrap.
#
# Validates:
# - repo structure
# - symlinks
# - shell modules
# - script permissions
# - Homebrew
# - PATH hygiene
# - Python
# - VS Code CLI
# - SSH agent (prefer 1Password)
# - Git tooling
#
# With --fix:
# - repairs deterministic issues
# - re-runs validation automatically
# =============================================================================

errors=0
warnings=0
FIX=0
CODE_CLI_AVAILABLE=0
FIX_APPLIED=0
RERUN_AFTER_FIX="${DOCTOR_RERUN_AFTER_FIX:-0}"

# -----------------------------------------------------------------------------
# Resolve repo root dynamically
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    -h|--help)
      echo "Usage: doctor.sh [--fix]"
      exit 0
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
section() { echo ""; echo "---- $1 ----"; }
ok() { echo "✔ $1"; }
warn() { echo "⚠ $1"; warnings=$((warnings + 1)); }
err() { echo "✖ $1"; errors=$((errors + 1)); }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

kv() {
  printf "%s: %s\n" "$1" "${2:-<unset>}"
}

mark_fix_applied() {
  FIX_APPLIED=1
}

backup_if_exists() {
  local target="$1"

  if [[ -e "$target" || -L "$target" ]]; then
    local ts backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.bak.${ts}"
    mv "$target" "$backup"
    echo "  Backed up: $target -> $backup"
  fi
}

repair_symlink() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    err "Cannot repair symlink, source missing: $source"
    return
  fi

  mkdir -p "$(dirname "$target")"
  backup_if_exists "$target"
  ln -sfn "$source" "$target"

  ok "Repaired symlink: $target -> $source"
  mark_fix_applied
}

check_expected_symlink() {
  local label="$1"
  local source="$2"
  local target="$3"

  if [[ ! -e "$source" ]]; then
    err "$label source missing: $source"
    return
  fi

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink "$target" || true)"

    if [[ "$current" == "$source" ]]; then
      ok "$label symlink OK"
      kv "$label target" "$target"
      kv "$label source" "$source"
      return
    fi

    warn "$label symlink incorrect"
    kv "$label current" "$current"
    kv "$label expected" "$source"

    if [[ "$FIX" -eq 1 ]]; then
      repair_symlink "$source" "$target"
    fi
    return
  fi

  if [[ -e "$target" ]]; then
    warn "$label exists but is not a symlink"
    kv "$label target" "$target"

    if [[ "$FIX" -eq 1 ]]; then
      repair_symlink "$source" "$target"
    fi
    return
  fi

  warn "$label missing"
  kv "$label target" "$target"

  if [[ "$FIX" -eq 1 ]]; then
    repair_symlink "$source" "$target"
  fi
}

check_readable_file() {
  local label="$1"
  local path="$2"

  if [[ -r "$path" ]]; then
    ok "$label present: $(basename "$path")"
  else
    err "$label missing: $path"
  fi
}

check_executable_file() {
  local label="$1"
  local path="$2"

  if [[ -x "$path" ]]; then
    ok "$label executable: $(basename "$path")"
    return
  fi

  warn "$label not executable: $path"

  if [[ "$FIX" -eq 1 && -e "$path" ]]; then
    chmod +x "$path"
    ok "Repaired executable bit: $(basename "$path")"
    mark_fix_applied
  fi
}

set_git_global() {
  local key="$1"
  local value="$2"

  git config --global "$key" "$value"
  mark_fix_applied
}

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
ZSH_BOOTSTRAP_SOURCE="$DOTFILES_ROOT/zshrc.bootstrap"
ZSHRC_TARGET="$HOME/.zshrc"

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_SETTINGS_SOURCE="$DOTFILES_ROOT/vscode/settings.json"
VSCODE_SETTINGS_TARGET="$VSCODE_USER_DIR/settings.json"
VSCODE_KEYBINDINGS_SOURCE="$DOTFILES_ROOT/vscode/keybindings.json"
VSCODE_KEYBINDINGS_TARGET="$VSCODE_USER_DIR/keybindings.json"

EXPECTED_GIT_EDITOR="code --wait"
EXPECTED_GIT_COMMIT_TEMPLATE="$DOTFILES_ROOT/git/commit-template"

# -----------------------------------------------------------------------------
# Declarative expectations
# -----------------------------------------------------------------------------
SYMLINK_SPECS=(
  "Zsh bootstrap|$ZSH_BOOTSTRAP_SOURCE|$ZSHRC_TARGET"
  "VS Code settings|$VSCODE_SETTINGS_SOURCE|$VSCODE_SETTINGS_TARGET"
  "VS Code keybindings|$VSCODE_KEYBINDINGS_SOURCE|$VSCODE_KEYBINDINGS_TARGET"
)

READABLE_FILES=(
  "$DOTFILES_ROOT/shell/10-base.zsh"
  "$DOTFILES_ROOT/shell/20-exports.zsh"
  "$DOTFILES_ROOT/shell/30-paths.zsh"
  "$DOTFILES_ROOT/shell/40-aliases.zsh"
)

EXECUTABLE_FILES=(
  "$DOTFILES_ROOT/scripts/install.sh"
  "$DOTFILES_ROOT/scripts/doctor.sh"
)

# -----------------------------------------------------------------------------
echo "== Dotfiles Doctor =="

section "Repo"
ok "Dotfiles root detected"
kv "root" "$DOTFILES_ROOT"

section "OS"
if [[ "${OSTYPE:-}" == darwin* ]]; then
  ok "macOS detected"
else
  warn "Non macOS environment"
fi

section "Shell / Bash"
if [[ "${BASH_VERSINFO[0]:-0}" -ge 4 ]]; then
  ok "Bash version ${BASH_VERSION}"
else
  err "Bash < 4 detected"
fi

section "Dotfiles links"
for spec in "${SYMLINK_SPECS[@]}"; do
  IFS='|' read -r label source target <<< "$spec"
  check_expected_symlink "$label" "$source" "$target"
done

section "Shell modules"
for file in "${READABLE_FILES[@]}"; do
  check_readable_file "Shell module" "$file"
done

section "Script permissions"
for file in "${EXECUTABLE_FILES[@]}"; do
  check_executable_file "Script" "$file"
done

section "Homebrew"
if have_cmd brew; then
  ok "brew found: $(command -v brew)"
  kv "brew prefix" "$(brew --prefix 2>/dev/null || true)"
else
  err "brew not found"
fi

section "PATH hygiene"
kv "PATH" "$PATH"

dup_count="$(
  echo "$PATH" | tr ':' '\n' | awk 'seen[$0]++{d++} END{print d+0}'
)"

if [[ "$dup_count" -eq 0 ]]; then
  ok "No PATH duplicates detected"
else
  warn "PATH duplicates detected"
fi

if have_cmd brew; then
  if [[ "$PATH" == /opt/homebrew/bin* || "$PATH" == /usr/local/bin* ]]; then
    ok "Homebrew appears early in PATH"
  else
    warn "Homebrew not early in PATH"
  fi
fi

section "Python"
if have_cmd python3; then
  ok "$(python3 --version)"
  kv "python3 path" "$(command -v python3)"
else
  warn "python3 not found"
fi

section "VS Code CLI"
if have_cmd code; then
  CODE_CLI_AVAILABLE=1
  ok "code CLI available ($(command -v code))"
else
  warn "'code' CLI not found in PATH"
  echo "Fix:"
  echo "VS Code -> Command Palette -> Install 'code' command in PATH"

  if [[ "$FIX" -eq 1 ]]; then
    if open -a "Visual Studio Code" >/dev/null 2>&1; then
      ok "Opened Visual Studio Code"
    else
      warn "Could not open VS Code automatically"
    fi
  fi
fi

section "SSH Agent"

OP_SSH_SOCK="$(
  find "$HOME/Library/Group Containers" -maxdepth 4 -type s -name agent.sock \
    -path "*com.1password*/t/agent.sock" 2>/dev/null | head -n 1 || true
)"

if [[ -n "$OP_SSH_SOCK" && -S "$OP_SSH_SOCK" ]]; then
  ok "1Password SSH agent detected"
  kv "socket" "$OP_SSH_SOCK"
else
  warn "1Password SSH agent not detected"
fi

if [[ "$FIX" -eq 1 && -n "$OP_SSH_SOCK" && "${SSH_AUTH_SOCK:-}" != "$OP_SSH_SOCK" ]]; then
  export SSH_AUTH_SOCK="$OP_SSH_SOCK"
  ok "SSH_AUTH_SOCK updated to 1Password agent"
  mark_fix_applied
fi

kv "SSH_AUTH_SOCK" "${SSH_AUTH_SOCK:-}"

if have_cmd ssh-add; then
  ssh_out="$(ssh-add -L 2>&1 || true)"

  if echo "$ssh_out" | grep -q "^ssh-"; then
    key_count="$(printf '%s\n' "$ssh_out" | grep -c "^ssh-" || true)"
    ok "SSH agent reachable ($key_count key(s) loaded)"
  elif echo "$ssh_out" | grep -qiE "could not open a connection|error connecting to agent|failed to connect to the agent"; then
    warn "SSH agent not accessible from this shell"
  elif echo "$ssh_out" | grep -qiE "no identities|the agent has no identities"; then
    warn "SSH agent reachable but no keys loaded"
  else
    warn "Unexpected ssh-add output (agent state unclear)"
  fi
else
  warn "ssh-add not available"
fi

section "Git tooling"
if have_cmd git; then
  editor="$(git config --global --get core.editor || true)"
  template="$(git config --global --get commit.template || true)"
  gpgfmt="$(git config --global --get gpg.format || true)"
  gpgsign="$(git config --global --get commit.gpgsign || true)"
  key="$(git config --global --get user.signingkey || true)"

  kv "core.editor" "$editor"
  kv "commit.template" "$template"
  kv "gpg.format" "$gpgfmt"
  kv "commit.gpgsign" "$gpgsign"
  kv "signingkey" "$key"

  if [[ "$editor" != "$EXPECTED_GIT_EDITOR" ]]; then
    if [[ "$CODE_CLI_AVAILABLE" -eq 1 ]]; then
      warn "Git editor not set correctly"
    else
      warn "Git editor not set correctly ('code' CLI unavailable)"
    fi

    if [[ "$FIX" -eq 1 && "$CODE_CLI_AVAILABLE" -eq 1 ]]; then
      set_git_global core.editor "$EXPECTED_GIT_EDITOR"
      ok "Repaired Git editor"
    elif [[ "$FIX" -eq 1 ]]; then
      warn "Skipped Git editor repair because 'code' CLI is unavailable"
    fi
  else
    ok "Git editor configured correctly"
  fi

  if [[ "$template" != "$EXPECTED_GIT_COMMIT_TEMPLATE" ]]; then
    warn "Git commit template not set correctly"
    if [[ "$FIX" -eq 1 ]]; then
      set_git_global commit.template "$EXPECTED_GIT_COMMIT_TEMPLATE"
      ok "Repaired commit template"
    fi
  else
    ok "Git commit template configured correctly"
  fi

  if [[ "$gpgfmt" == "ssh" && "$gpgsign" == "true" && -n "$key" ]]; then
    ok "Git SSH signing configured"
  else
    warn "Git SSH signing incomplete"
  fi
else
  warn "git not available"
fi

# -----------------------------------------------------------------------------
# Revalidation
# -----------------------------------------------------------------------------
if [[ "$FIX" -eq 1 && "$FIX_APPLIED" -eq 1 && "$RERUN_AFTER_FIX" -eq 0 ]]; then
  echo ""
  echo "Re-running doctor after applied fixes..."
  DOCTOR_RERUN_AFTER_FIX=1 exec bash "$0"
fi

# -----------------------------------------------------------------------------
echo ""

if [[ "$errors" -gt 0 ]]; then
  echo "Doctor finished with $errors error(s) and $warnings warning(s)"
  exit 1
fi

echo "Doctor completed with $warnings warning(s)"
exit 0
