#!/usr/bin/env zsh

# History configuration
export HISTSIZE=5000
export SAVEHIST=$HISTSIZE
export HISTDUP=erase

setopt INC_APPEND_HISTORY    # Immediately saves commands to history across sessions
setopt SHARE_HISTORY         # Share history across sessions
setopt HIST_IGNORE_ALL_DUPS  # To ignore duplicated commands history list
setopt HIST_SAVE_NO_DUPS     # Don't save duplicated entries
setopt HIST_FIND_NO_DUPS     # Don't display duplicates in search results
setopt HIST_IGNORE_SPACE     # Don't save commands starting with space

# Configure history-substring-search keybindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
