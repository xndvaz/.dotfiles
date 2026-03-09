# ------------------------------------------------------------
# Aliases configuration
# ------------------------------------------------------------
# Centralized command shortcuts.
# Keep this file focused on productivity helpers.
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

# Show commits that will be pushed from the current branch
glp() {
  local branch
  branch="$(git branch --show-current 2>/dev/null)"

  if [[ -z "$branch" ]]; then
    echo "Not on a Git branch." >&2
    return 1
  fi

  git log "origin/$branch..HEAD" --oneline
}

# ------------------------------------------------------------
# Git history cleanup
# ------------------------------------------------------------
# Interactive rebase of last N commits
# Example: gri 4
alias gri="git rebase -i"

# Squash last N commits quickly
# Example: grs 3
grs() {
  git reset --soft HEAD~$1 && git commit
}

# Amend last commit message
alias gamend="git commit --amend"

# ------------------------------------------------------------
# Conventional commits helpers
# ------------------------------------------------------------
# Fast helpers to generate Conventional Commit messages

gfeat() {
  git commit -m "feat($1): ${*:2}"
}

gfix() {
  git commit -m "fix($1): ${*:2}"
}

gdocs() {
  git commit -m "docs($1): ${*:2}"
}

gref() {
  git commit -m "refactor($1): ${*:2}"
}

gchore() {
  git commit -m "chore($1): ${*:2}"
}

gtest() {
  git commit -m "test($1): ${*:2}"
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
