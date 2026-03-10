# ------------------------------------------------------------
# Aliases configuration
# ------------------------------------------------------------
# Interactive shell shortcuts and small git helpers.
# Keep this file focused on user-invoked commands (no global exports).
# ------------------------------------------------------------

# ------------------------------------------------------------
# Git productivity
# ------------------------------------------------------------
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"

# Basic history
alias gl="git log --oneline --graph --decorate"

# Full readable history (great for reviewing commits)
alias glg="git log --graph --decorate --pretty=format:'%C(auto)%h %C(cyan)%ad %C(reset)%s %C(dim white)- %an%C(reset)' --date=relative"

_require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a Git repository." >&2
    return 1
  fi
}

# Show commits that will be pushed from the current branch
glp() {
  local branch
  local upstream

  _require_git_repo || return 1
  branch="$(git branch --show-current 2>/dev/null)"

  if [[ -z "$branch" ]]; then
    echo "Not on a Git branch." >&2
    return 1
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    echo "No upstream configured for branch '$branch'." >&2
    echo "Set one with: git push -u <remote> $branch" >&2
    return 1
  fi

  git log "$upstream..HEAD" --oneline
}

# ------------------------------------------------------------
# Git history cleanup
# ------------------------------------------------------------
# Interactive rebase of last N commits
# Example: gri 4
gri() {
  local n="${1:-}"

  if [[ -z "$n" || "$n" != <-> || "$n" -eq 0 ]]; then
    echo "Usage: gri <N>  # N must be a positive integer" >&2
    return 1
  fi

  _require_git_repo || return 1
  git rebase -i "HEAD~$n"
}

# Squash last N commits quickly
# Example: grs 3
grs() {
  local n="${1:-}"

  if [[ -z "$n" || "$n" != <-> || "$n" -eq 0 ]]; then
    echo "Usage: grs <N>  # N must be a positive integer" >&2
    return 1
  fi

  _require_git_repo || return 1
  git reset --soft "HEAD~$n" && git commit
}

# Amend last commit message
alias gamend="git commit --amend"

# ------------------------------------------------------------
# Conventional commits helpers
# ------------------------------------------------------------
# Fast helpers to generate Conventional Commit messages

_gcommit_cc() {
  local type="$1"
  local scope="${2:-}"

  _require_git_repo || return 1

  if [[ "$#" -lt 3 || -z "$scope" ]]; then
    echo "Usage: ${type} <scope> <description>" >&2
    return 1
  fi

  if ! [[ "$scope" =~ ^[a-z0-9._-]+$ ]]; then
    echo "Invalid scope '$scope'. Use only [a-z0-9._-]." >&2
    return 1
  fi

  shift 2
  git commit -m "${type}(${scope}): $*"
}

gfeat() {
  _gcommit_cc feat "$@"
}

gfix() {
  _gcommit_cc fix "$@"
}

gdocs() {
  _gcommit_cc docs "$@"
}

gref() {
  _gcommit_cc refactor "$@"
}

gchore() {
  _gcommit_cc chore "$@"
}

gtest() {
  _gcommit_cc test "$@"
}

# ------------------------------------------------------------
# Navigation
# ------------------------------------------------------------
alias ll="ls -lah"
alias ..="cd .."
alias ...="cd ../.."

# ------------------------------------------------------------
# VS Code convenience
# ------------------------------------------------------------
# Opens current directory in VS Code
alias c.="code ."

# ------------------------------------------------------------
# Python virtual environment helpers
# ------------------------------------------------------------
# Create .venv in current folder
alias venv="python3 -m venv .venv"

# Activate local virtual environment
alias act="source .venv/bin/activate"
