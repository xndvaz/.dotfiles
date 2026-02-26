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
# Prefer 1Password SSH agent if available (macOS).
# Falls back to whatever is already set by the system otherwise.

if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  # Try to discover 1Password agent socket (path may vary).
  for sock in "$HOME/Library/Group Containers/"*/com.1password/t/agent.sock; do
    if [[ -S "$sock" ]]; then
      export SSH_AUTH_SOCK="$sock"
      break
    fi
  done
fi
