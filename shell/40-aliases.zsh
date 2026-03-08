# ------------------------------------------------------------
# Aliases configuration
# ------------------------------------------------------------
# Centralized command shortcuts.
# Keep this file focused on productivity helpers.
# ------------------------------------------------------------

# ---- Git productivity ----
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gl="git log --oneline --graph --decorate"

# ---- Conventional commits helpers ----
# Fast helpers to generate Conventional Commit messages

gfeat() {
  git commit -m "feat($1): ${@:2}"
}

gfix() {
  git commit -m "fix($1): ${@:2}"
}

gdocs() {
  git commit -m "docs($1): ${@:2}"
}

gref() {
  git commit -m "refactor($1): ${@:2}"
}

gchore() {
  git commit -m "chore($1): ${@:2}"
}

gtest() {
  git commit -m "test($1): ${@:2}"
}

# ---- Navigation ----
alias ll="ls -lah"
alias ..="cd .."
alias ...="cd ../.."

# ---- VS Code convenience ----
# Opens current directory in VS Code
alias c.="code ."

# ---- Python virtual environment helpers ----
# Create .venv in current folder
alias venv="python3 -m venv .venv"

# Activate local virtual environment
alias act="source .venv/bin/activate"