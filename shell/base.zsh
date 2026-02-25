# ------------------------------------------------------------
# Base shell behavior configuration
# ------------------------------------------------------------
# Core ZSH behavior settings and history configuration.
# This file should not contain aliases or environment variables.
# ------------------------------------------------------------

# Enable autocompletion
autoload -Uz compinit
compinit

# History configuration
HISTSIZE=5000          # Number of commands kept in memory
SAVEHIST=5000          # Number of commands saved to file
HISTFILE=~/.zsh_history

# History behavior improvements
setopt appendhistory           # Append history instead of overwrite
setopt sharehistory            # Share history across sessions
setopt hist_ignore_dups        # Ignore duplicated commands
setopt hist_ignore_all_dups    # Remove older duplicate entries
setopt hist_find_no_dups       # Do not show duplicates in search