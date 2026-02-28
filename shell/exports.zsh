# ------------------------------------------------------------
# Environment variables
# ------------------------------------------------------------
# Global environment variables configuration.
# Keep secrets OUT of this file.
# ------------------------------------------------------------

# Default editor for CLI programs
export EDITOR="code"
export VISUAL="code"

# ------------------------------------------------------------
# SSH Agent (1Password)
# ------------------------------------------------------------
# Prefer 1Password SSH agent when available.
# VS Code integrated terminals often inherit macOS launchd SSH_AUTH_SOCK,
# which results in "no identities" even though 1Password SSH Agent is enabled.
#
# Strategy:
# - Discover 1Password agent socket (macOS) via a safe search.
# - If found, override SSH_AUTH_SOCK when:
#   - SSH_AUTH_SOCK is unset, OR
#   - SSH_AUTH_SOCK points to launchd (macOS system agent), OR
#   - SSH_AUTH_SOCK is set but the socket path is invalid (stale).
#
# Notes:
# - macOS-only (as requested).
# - Keep this file free of secrets; it only points to a local socket.
# ------------------------------------------------------------

# Attempt to locate the 1Password agent socket.
# Typical path (1Password 8):
#   ~/Library/Group Containers/<TEAMID>.com.1password/t/agent.sock
OP_SSH_SOCK="$(
  find "$HOME/Library/Group Containers" \
    -maxdepth 4 \
    -type s \
    -name "agent.sock" \
    -path "*com.1password*/t/agent.sock" \
    -print 2>/dev/null | head -n 1
)"

# If 1Password socket exists, prefer it over launchd/system sockets.
if [[ -n "${OP_SSH_SOCK:-}" && -S "$OP_SSH_SOCK" ]]; then
  if [[ -z "${SSH_AUTH_SOCK:-}" || "$SSH_AUTH_SOCK" == *"com.apple.launchd"* || ! -S "$SSH_AUTH_SOCK" ]]; then
    export SSH_AUTH_SOCK="$OP_SSH_SOCK"
  fi
fi