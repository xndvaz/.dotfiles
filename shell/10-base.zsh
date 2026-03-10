# ------------------------------------------------------------
# Base shell behavior configuration
# ------------------------------------------------------------
# Core ZSH behavior settings and history configuration.
# This file should not contain aliases or environment variables.
# ------------------------------------------------------------

# Enable autocompletion (cached for faster startup)
autoload -Uz compinit
zmodload -F zsh/stat b:zstat 2>/dev/null || true

typeset -i _compinit_rebuild=1
typeset -i _compinit_max_age=86400 # 24h
typeset _zcompdump_path="${ZDOTDIR:-$HOME}/.zcompdump"

if [[ -r "$_zcompdump_path" ]]; then
  _compinit_rebuild=0

  if (( $+builtins[zstat] )); then
    typeset -A _zcompdump_stat
    if zstat -A _zcompdump_stat +mtime -- "$_zcompdump_path" 2>/dev/null; then
      (( EPOCHSECONDS - _zcompdump_stat[mtime] > _compinit_max_age )) && _compinit_rebuild=1
    else
      _compinit_rebuild=1
    fi
  fi
fi

if (( _compinit_rebuild )); then
  compinit -d "$_zcompdump_path"
else
  compinit -C -d "$_zcompdump_path"
fi

unset _compinit_rebuild _compinit_max_age _zcompdump_path _zcompdump_stat

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
