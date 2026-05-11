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
#
# With --dry-run:
# - prints planned fix actions without applying them
# =============================================================================

errors=0
warnings=0
FIX=0
NON_INTERACTIVE=0
DRY_RUN=0
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
  --non-interactive) NON_INTERACTIVE=1 ;;
  --dry-run) DRY_RUN=1 ;;
  -h | --help)
    echo "Usage: doctor.sh [--fix] [--non-interactive] [--dry-run]"
    exit 0
    ;;
  *)
    echo "Error: unknown argument: $arg" >&2
    echo "Usage: doctor.sh [--fix] [--non-interactive] [--dry-run]" >&2
    exit 1
    ;;
  esac
done

if [[ "$NON_INTERACTIVE" -eq 0 && ! -t 0 ]]; then
  NON_INTERACTIVE=1
  echo "Notice: stdin is not a TTY. Enabling non-interactive mode."
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Notice: --dry-run enabled. No fixes will be written."
fi

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
section() {
  echo ""
  echo "---- $1 ----"
}
ok() { echo "✔ $1"; }
warn() {
  echo "⚠ $1"
  warnings=$((warnings + 1))
}
err() {
  echo "✖ $1"
  errors=$((errors + 1))
}
dry_note() { echo "[dry-run] $1"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_1password_agent_socket() {
  local pattern="$HOME/Library/Group Containers/*.com.1password*/t/agent.sock"
  local -a socket_candidates=()
  local socket_path

  mapfile -t socket_candidates < <(compgen -G "$pattern" || true)

  for socket_path in "${socket_candidates[@]}"; do
    if [[ -S "$socket_path" ]]; then
      printf '%s\n' "$socket_path"
      return 0
    fi
  done

  return 1
}

kv() {
  printf "%s: %s\n" "$1" "${2:-<unset>}"
}

path_index_of() {
  local needle="$1"
  local idx=1
  local entry
  local -a path_entries
  IFS=':' read -r -a path_entries <<<"$PATH"

  for entry in "${path_entries[@]}"; do
    if [[ "$entry" == "$needle" ]]; then
      echo "$idx"
      return 0
    fi
    idx=$((idx + 1))
  done

  echo 0
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
    if [[ "$DRY_RUN" -eq 1 ]]; then
      dry_note "Would back up: $target -> $backup"
    else
      mv "$target" "$backup"
      echo "  Backed up: $target -> $backup"
    fi
  fi
}

repair_symlink() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    err "Cannot repair symlink, source missing: $source"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_note "Would repair symlink: $target -> $source"
  else
    mkdir -p "$(dirname "$target")"
    backup_if_exists "$target"
    ln -sfn "$source" "$target"

    ok "Repaired symlink: $target -> $source"
    mark_fix_applied
  fi
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
    if [[ "$DRY_RUN" -eq 1 ]]; then
      dry_note "Would set executable bit on: $path"
    else
      chmod +x "$path"
      ok "Repaired executable bit: $(basename "$path")"
      mark_fix_applied
    fi
  fi
}

set_git_global() {
  local key="$1"
  local value="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_note "Would configure git --global $key=$value"
  else
    git config --global "$key" "$value"
    mark_fix_applied
  fi
}

check_required_command() {
  local cmd="$1"
  if have_cmd "$cmd"; then
    ok "$cmd available: $(command -v "$cmd")"
  else
    warn "$cmd not found in PATH"
  fi
}

is_vscode_extension_id() {
  local value="${1,,}"
  [[ "$value" =~ ^[a-z0-9][a-z0-9.-]*\.[a-z0-9][a-z0-9.-]*$ ]]
}

collect_vscode_extensions() {
  local ext
  {
    code --list-extensions 2>/dev/null || true
  } | while IFS= read -r ext; do
    ext="${ext,,}"
    if is_vscode_extension_id "$ext"; then
      printf '%s\n' "$ext"
    fi
  done | awk '!seen[$0]++'
}

check_and_prune_vscode_extensions() {
  local baseline_file="$1"
  local ext
  local extra
  local failures=0
  local baseline_tmp
  local cleanup_tmp=0
  local -a installed_exts=()
  local -a extras=()

  if [[ "$CODE_CLI_AVAILABLE" -ne 1 ]]; then
    warn "Skipping VS Code extension baseline check ('code' CLI unavailable)"
    return
  fi

  if [[ ! -f "$baseline_file" ]]; then
    warn "VS Code extension baseline missing: $baseline_file"
    return
  fi

  baseline_tmp="$(mktemp)"
  cleanup_tmp=1

  while IFS= read -r ext || [[ -n "$ext" ]]; do
    ext="${ext#"${ext%%[![:space:]]*}"}"
    ext="${ext%"${ext##*[![:space:]]}"}"
    ext="${ext,,}"
    [[ -z "$ext" ]] && continue
    [[ "$ext" == \#* ]] && continue
    if ! is_vscode_extension_id "$ext"; then
      continue
    fi
    printf '%s\n' "$ext" >>"$baseline_tmp"
  done <"$baseline_file"

  sort -u "$baseline_tmp" -o "$baseline_tmp"
  mapfile -t installed_exts < <(collect_vscode_extensions)

  for ext in "${installed_exts[@]}"; do
    if ! grep -Fxq "$ext" "$baseline_tmp"; then
      extras+=("$ext")
    fi
  done

  if [[ "${#extras[@]}" -eq 0 ]]; then
    ok "VS Code extensions aligned with baseline"
    rm -f "$baseline_tmp"
    return
  fi

  warn "Found ${#extras[@]} VS Code extension(s) outside baseline"
  for extra in "${extras[@]}"; do
    echo "  - $extra"
  done

  if [[ "$FIX" -ne 1 ]]; then
    rm -f "$baseline_tmp"
    return
  fi

  for extra in "${extras[@]}"; do
    if [[ "$DRY_RUN" -eq 1 ]]; then
      dry_note "Would uninstall VS Code extension: $extra"
      continue
    fi

    if code --uninstall-extension "$extra" >/dev/null 2>&1; then
      echo "  Removed extension: $extra"
      mark_fix_applied
    else
      warn "Failed to uninstall VS Code extension: $extra"
      failures=$((failures + 1))
    fi
  done

  if [[ "$DRY_RUN" -eq 1 ]]; then
    ok "Planned VS Code extension prune (dry-run)"
  elif [[ "$failures" -eq 0 ]]; then
    ok "Pruned VS Code extensions to baseline"
  fi

  if [[ "$cleanup_tmp" -eq 1 ]]; then
    rm -f "$baseline_tmp"
  fi
}

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
ZSH_BOOTSTRAP_SOURCE="$DOTFILES_ROOT/zshrc.bootstrap"
ZSHRC_TARGET="$HOME/.zshrc"
BASHRC_SOURCE="$DOTFILES_ROOT/shell/bashrc"
BASHRC_TARGET="$HOME/.bashrc"

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_SETTINGS_SOURCE="$DOTFILES_ROOT/vscode/settings.json"
VSCODE_SETTINGS_TARGET="$VSCODE_USER_DIR/settings.json"
VSCODE_KEYBINDINGS_SOURCE="$DOTFILES_ROOT/vscode/keybindings.json"
VSCODE_KEYBINDINGS_TARGET="$VSCODE_USER_DIR/keybindings.json"
VSCODE_EXTENSIONS_BASELINE="$DOTFILES_ROOT/vscode/extensions.txt"

CODEX_AGENTS_SOURCE="$DOTFILES_ROOT/codex/AGENTS.md"
CODEX_AGENTS_TARGET="$HOME/.codex/AGENTS.md"
CODEX_CONFIG_SOURCE="$DOTFILES_ROOT/codex/config.toml"
CODEX_CONFIG_TARGET="$HOME/.codex/config.toml"
CODEX_SKILLS_SOURCE="$DOTFILES_ROOT/skills"
CODEX_SKILLS_TARGET="$HOME/.codex/skills"

EXPECTED_GIT_EDITOR="code --wait"
EXPECTED_GIT_COMMIT_TEMPLATE="$DOTFILES_ROOT/git/commit-template"
EXPECTED_GIT_HOOKS_PATH="$DOTFILES_ROOT/scripts/hooks"
EXPECTED_ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"

# -----------------------------------------------------------------------------
# Declarative expectations
# -----------------------------------------------------------------------------
SYMLINK_SPECS=(
  "Zsh bootstrap|$ZSH_BOOTSTRAP_SOURCE|$ZSHRC_TARGET"
  "Bash bootstrap|$BASHRC_SOURCE|$BASHRC_TARGET"
  "VS Code settings|$VSCODE_SETTINGS_SOURCE|$VSCODE_SETTINGS_TARGET"
  "VS Code keybindings|$VSCODE_KEYBINDINGS_SOURCE|$VSCODE_KEYBINDINGS_TARGET"
  "Codex AGENTS|$CODEX_AGENTS_SOURCE|$CODEX_AGENTS_TARGET"
  "Codex config|$CODEX_CONFIG_SOURCE|$CODEX_CONFIG_TARGET"
  "Codex skills|$CODEX_SKILLS_SOURCE|$CODEX_SKILLS_TARGET"
)

READABLE_FILES=(
  "$DOTFILES_ROOT/shell/10-base.zsh"
  "$DOTFILES_ROOT/shell/20-exports.zsh"
  "$DOTFILES_ROOT/shell/30-paths.zsh"
  "$DOTFILES_ROOT/shell/40-aliases.zsh"
  "$DOTFILES_ROOT/shell/bashrc"
)

EXECUTABLE_FILES=(
  "$DOTFILES_ROOT/scripts/install.sh"
  "$DOTFILES_ROOT/scripts/doctor.sh"
  "$DOTFILES_ROOT/scripts/test-install-flags.sh"
  "$DOTFILES_ROOT/scripts/test-doctor-flags.sh"
  "$DOTFILES_ROOT/scripts/test-doctor-vscode-prune.sh"
  "$DOTFILES_ROOT/scripts/test-pre-commit-gate.sh"
  "$DOTFILES_ROOT/scripts/hooks/pre-commit"
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
  IFS='|' read -r label source target <<<"$spec"
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

section "Required tooling"
check_required_command gh
check_required_command node
check_required_command shellcheck
check_required_command git-cliff
check_required_command go

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
  brew_bin_dir="$(dirname "$(command -v brew)")"
  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  brew_sbin_dir=""

  if [[ -n "$brew_prefix" ]]; then
    brew_sbin_dir="$brew_prefix/sbin"
  fi

  brew_bin_pos="$(path_index_of "$brew_bin_dir")"
  brew_sbin_pos=0
  if [[ -n "$brew_sbin_dir" ]]; then
    brew_sbin_pos="$(path_index_of "$brew_sbin_dir")"
  fi

  sys_usrbin_pos="$(path_index_of "/usr/bin")"
  sys_bin_pos="$(path_index_of "/bin")"

  brew_best_pos=0
  if [[ "$brew_bin_pos" -gt 0 ]]; then
    brew_best_pos="$brew_bin_pos"
  fi
  if [[ "$brew_sbin_pos" -gt 0 && ("$brew_best_pos" -eq 0 || "$brew_sbin_pos" -lt "$brew_best_pos") ]]; then
    brew_best_pos="$brew_sbin_pos"
  fi

  sys_best_pos=0
  if [[ "$sys_usrbin_pos" -gt 0 ]]; then
    sys_best_pos="$sys_usrbin_pos"
  fi
  if [[ "$sys_bin_pos" -gt 0 && ("$sys_best_pos" -eq 0 || "$sys_bin_pos" -lt "$sys_best_pos") ]]; then
    sys_best_pos="$sys_bin_pos"
  fi

  if [[ "$brew_best_pos" -eq 0 ]]; then
    warn "Homebrew directories not found in PATH"
  elif [[ "$sys_best_pos" -eq 0 || "$brew_best_pos" -lt "$sys_best_pos" ]]; then
    ok "Homebrew precedes system directories in PATH"
  else
    warn "Homebrew comes after system directories in PATH"
  fi

  kv "brew bin path index" "$brew_bin_pos"
  if [[ -n "$brew_sbin_dir" ]]; then
    kv "brew sbin path index" "$brew_sbin_pos"
  fi
  kv "/usr/bin path index" "$sys_usrbin_pos"
  kv "/bin path index" "$sys_bin_pos"
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
    if [[ "$DRY_RUN" -eq 1 ]]; then
      dry_note "Would open Visual Studio Code for CLI setup guidance"
    elif [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      ok "Non-interactive mode: skipped automatic VS Code launch"
    elif open -a "Visual Studio Code" >/dev/null 2>&1; then
      ok "Opened Visual Studio Code"
    else
      warn "Could not open VS Code automatically"
    fi
  fi
fi

section "VS Code Extensions"
check_and_prune_vscode_extensions "$VSCODE_EXTENSIONS_BASELINE"

section "SSH Agent"

OP_SSH_SOCK="$(detect_1password_agent_socket || true)"

if [[ -n "$OP_SSH_SOCK" && -S "$OP_SSH_SOCK" ]]; then
  ok "1Password SSH agent detected"
  kv "socket" "$OP_SSH_SOCK"
else
  warn "1Password SSH agent not detected"
fi

if [[ "$FIX" -eq 1 && -n "$OP_SSH_SOCK" && "${SSH_AUTH_SOCK:-}" != "$OP_SSH_SOCK" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_note "Would set SSH_AUTH_SOCK to 1Password agent socket"
  else
    export SSH_AUTH_SOCK="$OP_SSH_SOCK"
    ok "SSH_AUTH_SOCK updated to 1Password agent"
    mark_fix_applied
  fi
fi

if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  if [[ -S "$SSH_AUTH_SOCK" ]]; then
    kv "SSH_AUTH_SOCK" "$SSH_AUTH_SOCK"
  else
    warn "SSH_AUTH_SOCK is set but not a valid socket (stale/invalid)"
    kv "SSH_AUTH_SOCK" "$SSH_AUTH_SOCK"
  fi
else
  kv "SSH_AUTH_SOCK" "<unset>"
fi

if have_cmd ssh-add; then
  ssh_out="$(ssh-add -L 2>&1 || true)"

  if echo "$ssh_out" | grep -qE "^(ssh-|ecdsa-|sk-)"; then
    key_count="$(printf '%s\n' "$ssh_out" | grep -Ec "^(ssh-|ecdsa-|sk-)" || true)"
    ok "SSH agent reachable ($key_count key(s) loaded)"
  elif echo "$ssh_out" | grep -qiE "could not open a connection|error connecting to agent|failed to connect to the agent"; then
    warn "SSH agent not accessible from this shell"
    if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
      echo "Hint: SSH_AUTH_SOCK points to a valid socket but agent communication failed."
      echo "Hint: Unlock 1Password and verify SSH Agent is enabled."
      echo "Hint: Re-run with explicit socket to inspect output:"
      echo "      SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\" ssh-add -L"
    else
      echo "Hint: SSH_AUTH_SOCK is missing or invalid for this shell."
      echo "Hint: Run doctor with --fix to align SSH_AUTH_SOCK when 1Password agent is detected."
    fi
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
  hooks_path="$(git config --global --get core.hooksPath || true)"
  gpgfmt="$(git config --global --get gpg.format || true)"
  gpgsign="$(git config --global --get commit.gpgsign || true)"
  key="$(git config --global --get user.signingkey || true)"
  allowed_signers_file="$(git config --global --get gpg.ssh.allowedSignersFile || true)"

  kv "core.editor" "$editor"
  kv "commit.template" "$template"
  kv "core.hooksPath" "$hooks_path"
  kv "gpg.format" "$gpgfmt"
  kv "commit.gpgsign" "$gpgsign"
  kv "signingkey" "$key"
  kv "gpg.ssh.allowedSignersFile" "$allowed_signers_file"

  if [[ "$editor" != "$EXPECTED_GIT_EDITOR" ]]; then
    if [[ "$CODE_CLI_AVAILABLE" -eq 1 ]]; then
      warn "Git editor not set correctly"
    else
      warn "Git editor not set correctly ('code' CLI unavailable)"
    fi

    if [[ "$FIX" -eq 1 && "$CODE_CLI_AVAILABLE" -eq 1 ]]; then
      set_git_global core.editor "$EXPECTED_GIT_EDITOR"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        ok "Planned Git editor repair (dry-run)"
      else
        ok "Repaired Git editor"
      fi
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
      if [[ "$DRY_RUN" -eq 1 ]]; then
        ok "Planned commit template repair (dry-run)"
      else
        ok "Repaired commit template"
      fi
    fi
  else
    ok "Git commit template configured correctly"
  fi

  if [[ "$hooks_path" != "$EXPECTED_GIT_HOOKS_PATH" ]]; then
    warn "Git hooks path not set correctly"
    if [[ "$FIX" -eq 1 ]]; then
      set_git_global core.hooksPath "$EXPECTED_GIT_HOOKS_PATH"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        ok "Planned hooks path repair (dry-run)"
      else
        ok "Repaired hooks path"
      fi
    fi
  else
    ok "Git hooks path configured correctly"
  fi

  if [[ "$allowed_signers_file" != "$EXPECTED_ALLOWED_SIGNERS" ]]; then
    warn "Git allowed signers file not set correctly"
    if [[ "$FIX" -eq 1 ]]; then
      set_git_global gpg.ssh.allowedSignersFile "$EXPECTED_ALLOWED_SIGNERS"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        ok "Planned allowed signers config repair (dry-run)"
      else
        ok "Repaired allowed signers config"
      fi
    fi
  else
    ok "Git allowed signers file configured correctly"
  fi

  if [[ -f "$EXPECTED_ALLOWED_SIGNERS" ]]; then
    ok "allowed_signers file exists"
  else
    warn "allowed_signers file missing: $EXPECTED_ALLOWED_SIGNERS"
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
  rerun_args=()
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    rerun_args+=(--non-interactive)
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    rerun_args+=(--dry-run)
  fi

  echo ""
  echo "Re-running doctor after applied fixes..."
  DOCTOR_RERUN_AFTER_FIX=1 exec bash "$0" "${rerun_args[@]}"
fi

# -----------------------------------------------------------------------------
echo ""

if [[ "$errors" -gt 0 ]]; then
  echo "Doctor finished with $errors error(s) and $warnings warning(s)"
  exit 1
fi

echo "Doctor completed with $warnings warning(s)"
exit 0
