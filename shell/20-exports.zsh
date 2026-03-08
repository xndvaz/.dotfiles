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
# - Discover 1Password agent socket using Zsh globbing (no external processes).
# - If found, override SSH_AUTH_SOCK when:
#   - SSH_AUTH_SOCK is unset, OR
#   - SSH_AUTH_SOCK points to launchd (macOS system agent), OR
#   - SSH_AUTH_SOCK is set but the socket path is invalid (stale).
#
# Notes:
# - macOS-only.
# - This file contains no secrets, only a local socket path.
# ------------------------------------------------------------

if [[ "$OSTYPE" == darwin* ]]; then

  # Zsh glob search for 1Password SSH agent socket
  typeset -a op_agent_sockets
  op_agent_sockets=("$HOME/Library/Group Containers"/*.com.1password/t/agent.sock(N))

  # Use the first match if present
  if (( ${#op_agent_sockets[@]} > 0 )) && [[ -S "${op_agent_sockets[1]}" ]]; then
    OP_SSH_SOCK="${op_agent_sockets[1]}"

    # Override SSH_AUTH_SOCK only when necessary
    if [[ -z "${SSH_AUTH_SOCK:-}" \
       || "$SSH_AUTH_SOCK" == *"com.apple.launchd"* \
       || ! -S "$SSH_AUTH_SOCK" ]]; then
      export SSH_AUTH_SOCK="$OP_SSH_SOCK"
    fi
  fi

fi