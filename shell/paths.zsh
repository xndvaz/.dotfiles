# ------------------------------------------------------------
# PATH configuration
# ------------------------------------------------------------
# macOS-only, "hard-to-break" PATH setup.
#
# Goals:
# - Prefer Homebrew (Apple Silicon or Intel) when available.
# - Avoid PATH duplication (clean + predictable precedence).
# - Work consistently in Terminal.app/iTerm and VS Code integrated terminal.
#
# Notes:
# - Uses zsh features (this is fine: macOS default shell is zsh).
# - Keep secrets OUT of this file.
# ------------------------------------------------------------

# ------------------------------------------------------------
# PATH utilities (no duplicates)
# ------------------------------------------------------------
path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;; # already present
    *) PATH="$1:$PATH" ;;
  esac
}

path_append() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

# ------------------------------------------------------------
# Homebrew (macOS)
# ------------------------------------------------------------
# Prefer initializing Homebrew via `brew shellenv` instead of hardcoding paths.
# This sets:
# - PATH (brew bins first)
# - HOMEBREW_PREFIX / HOMEBREW_CELLAR / HOMEBREW_REPOSITORY
#
# We only run it if it hasn't been initialized yet (HOMEBREW_PREFIX unset).
# ------------------------------------------------------------
if [[ "$OSTYPE" == darwin* && -z "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# ------------------------------------------------------------
# User-local bins (optional, but convenient)
# ------------------------------------------------------------
# Put your own scripts before system tools.
path_prepend "$HOME/.local/bin"

# ------------------------------------------------------------
# Deduplicate PATH (zsh-only)
# ------------------------------------------------------------
# `path` is the zsh array representation of $PATH.
# Making it unique removes duplicates while preserving the first occurrence.
typeset -U path
export PATH