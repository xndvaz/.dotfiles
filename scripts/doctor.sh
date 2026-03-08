#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# dotfiles doctor (macOS-first)
# -----------------------------------------------------------------------------
# Quick diagnostics for your workstation environment.
#
# SSH behavior:
# - Prefer 1Password SSH agent if available.
# - If 1Password agent is not available, fall back to macOS (launchd) agent.
# - With --fix: export SSH_AUTH_SOCK to 1Password socket for THIS shell session.
#
# Important:
# - This script ALWAYS prints the full report.
# - --fix only changes behavior (it does not change verbosity).
#
# Exit codes:
# - 0: no hard errors (warnings may exist)
# - 1: at least one error detected
# =============================================================================

errors=0
warnings=0
FIX=0

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    -h|--help)
      echo "Usage: doctor.sh [--fix]"
      echo "  --fix   Prefer 1Password SSH agent for this session by exporting SSH_AUTH_SOCK."
      exit 0
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
section() { echo ""; echo "---- $1 ----"; }
ok()   { echo "✔ $1"; }
warn() { echo "⚠ $1"; warnings=$((warnings + 1)); }
err()  { echo "✖ $1"; errors=$((errors + 1)); }

have_cmd() { command -v "$1" >/dev/null 2>&1; }
kv() { printf "%s: %s\n" "$1" "${2:-<unset>}"; }

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------
echo "== Dotfiles Doctor =="

# -----------------------------------------------------------------------------
section "OS"
if [[ "${OSTYPE:-}" == darwin* ]]; then
  ok "macOS detected (${OSTYPE})"
else
  warn "Not macOS (OSTYPE=${OSTYPE:-unknown}). Some checks may be inaccurate."
fi

# -----------------------------------------------------------------------------
section "Shell / Bash"
# Bash 4+ is required by other scripts (install.sh uses mapfile).
if [[ -n "${BASH_VERSINFO:-}" && "${BASH_VERSINFO[0]}" -ge 4 ]]; then
  ok "Bash version: ${BASH_VERSION}"
else
  err "Bash < 4 detected: ${BASH_VERSION:-unknown} (fix: brew install bash)"
fi

# -----------------------------------------------------------------------------
section "Homebrew"
if have_cmd brew; then
  brew_path="$(command -v brew)"
  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  ok "brew found: ${brew_path}"
  [[ -n "$brew_prefix" ]] && ok "brew --prefix: ${brew_prefix}" || warn "brew --prefix failed"
else
  err "brew not found in PATH"
fi

# -----------------------------------------------------------------------------
section "PATH hygiene"
# Print PATH so precedence issues are visible.
kv "PATH" "${PATH:-}"

# Detect duplicates in PATH (usually harmless, but confusing).
dup_count="$(
  echo "${PATH:-}" | tr ':' '\n' | awk 'seen[$0]++{d++} END{print d+0}'
)"

if [[ "${dup_count}" -eq 0 ]]; then
  ok "No PATH duplicates detected"
else
  warn "PATH contains duplicate entries (${dup_count}). Not fatal, but can complicate debugging."
fi

# Ensure Homebrew is early in PATH so brew tools override system tools.
if have_cmd brew; then
  if [[ "${PATH:-}" == /opt/homebrew/bin* || "${PATH:-}" == /usr/local/bin* ]]; then
    ok "Homebrew appears early in PATH"
  else
    warn "Homebrew not early in PATH. You may see system tools shadowing brew tools."
  fi
fi

# -----------------------------------------------------------------------------
section "Python"
if have_cmd python3; then
  py_path="$(command -v python3)"
  py_version="$(python3 --version 2>&1 || true)"
  ok "python3: ${py_version} (${py_path})"

  # Prefer brew python when brew is installed (macOS system python can be old).
  if have_cmd brew; then
    if [[ "$py_path" == *"/opt/homebrew/"* || "$py_path" == *"/usr/local/"* ]]; then
      ok "python3 is from Homebrew"
    else
      warn "python3 is not from Homebrew (${py_path}). If you expect brew python, check PATH ordering."
    fi
  fi
else
  warn "python3 not found (some checks may be reduced)"
fi

# -----------------------------------------------------------------------------
section "VS Code CLI"
if have_cmd code; then
  ok "code CLI available ($(command -v code))"
else
  warn "'code' CLI not found in PATH (fix: VS Code -> Command Palette -> Install 'code' command in PATH)"
fi

# -----------------------------------------------------------------------------
section "SSH Agent"
# Prefer 1Password. If present:
# - In normal mode: warn if current shell is not using it.
# - With --fix: export SSH_AUTH_SOCK to force it for this session.

# Find 1Password agent socket (typical 1Password 8 location).
# With pipefail enabled, make this pipeline non-fatal with `|| true`.
OP_SSH_SOCK="$(
  find "$HOME/Library/Group Containers" -maxdepth 4 -type s -name "agent.sock" \
    -path "*com.1password*/t/agent.sock" -print 2>/dev/null | head -n 1 || true
)"

op_available=0
if [[ -n "${OP_SSH_SOCK:-}" && -S "$OP_SSH_SOCK" ]]; then
  op_available=1
  ok "1Password agent socket found"
  kv "1Password socket" "$OP_SSH_SOCK"
else
  warn "1Password agent socket not found (if you use 1Password SSH Agent, confirm it's enabled)"
fi

# If --fix and 1Password socket exists, force it for this session.
if [[ "$FIX" -eq 1 && "$op_available" -eq 1 ]]; then
  export SSH_AUTH_SOCK="$OP_SSH_SOCK"
  ok "--fix applied: SSH_AUTH_SOCK set to 1Password socket (this session only)"
fi

# Show the active socket and whether it is valid.
kv "SSH_AUTH_SOCK" "${SSH_AUTH_SOCK:-}"

# Identify when the active agent looks like the macOS launchd agent.
if [[ -n "${SSH_AUTH_SOCK:-}" && "${SSH_AUTH_SOCK}" == *"com.apple.launchd"* ]]; then
  warn "Active SSH agent appears to be macOS launchd (not 1Password)."
fi

sock="${SSH_AUTH_SOCK:-}"
if [[ -n "$sock" && -S "$sock" ]]; then
  ok "SSH_AUTH_SOCK points to a valid socket"
else
  warn "SSH_AUTH_SOCK is unset or not a valid socket"
fi

# If 1Password is available but this shell is not using it, warn with a fix.
if [[ "$FIX" -eq 0 && "$op_available" -eq 1 ]]; then
  if [[ -n "${SSH_AUTH_SOCK:-}" && "${SSH_AUTH_SOCK}" != "$OP_SSH_SOCK" ]]; then
    warn "This shell is NOT using 1Password SSH agent (recommended). Fix: doctor.sh --fix"
  fi
fi

# Agent reachability and keys.
if have_cmd ssh-add; then
  ssh_add_out="$(ssh-add -L 2>&1 || true)"

  if echo "$ssh_add_out" | grep -qiE "could not open a connection|error connecting to agent"; then
    warn "SSH agent not accessible from this shell"
  elif echo "$ssh_add_out" | grep -qiE "no identities|the agent has no identities"; then
    warn "SSH agent reachable but has no identities loaded"
    if [[ "$op_available" -eq 1 ]]; then
      echo "  Fix: doctor.sh --fix (then ensure your key is enabled/authorized in 1Password SSH Agent)."
    else
      echo "  Fix: load a key into your SSH agent (or enable 1Password SSH Agent)."
    fi
  elif echo "$ssh_add_out" | grep -qE "^ssh-"; then
    key_lines="$(echo "$ssh_add_out" | grep -cE '^ssh-' || true)"
    ok "SSH agent reachable (${key_lines} key(s) loaded)"
  else
    warn "Unexpected ssh-add output (agent state unclear)"
  fi
else
  warn "ssh-add not available"
fi

# -----------------------------------------------------------------------------
section "Git SSH signing"
if have_cmd git; then
  fmt="$(git config --global --get gpg.format || true)"
  sign="$(git config --global --get commit.gpgsign || true)"
  key="$(git config --global --get user.signingkey || true)"

  kv "git gpg.format" "${fmt:-<unset>}"
  kv "git commit.gpgsign" "${sign:-<unset>}"
  kv "git user.signingkey" "${key:-<unset>}"

  if [[ "$fmt" == "ssh" && "$sign" == "true" && -n "$key" ]]; then
    ok "Git SSH signing configured"
  else
    warn "Git SSH signing not fully configured (expected: gpg.format=ssh, commit.gpgsign=true, user.signingkey set)"
  fi
else
  warn "git not found"
fi

# -----------------------------------------------------------------------------
# Summary / exit code
# -----------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "== Doctor completed with ${errors} error(s), ${warnings} warning(s) =="
  exit 1
fi

echo "== Doctor completed with ${warnings} warning(s) =="
exit 0