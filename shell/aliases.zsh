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