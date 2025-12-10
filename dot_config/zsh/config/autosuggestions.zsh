#!/usr/bin/env zsh

# Auto-suggestions configuration
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  'bracketed-paste'
  'history-search-forward'
  'history-search-backward'
  'history-beginning-search-forward'
  'history-beginning-search-backward'
  'history-substring-search-up'
  'history-substring-search-down'
  'up-line-or-beginning-search'
  'down-line-or-beginning-search'
  'up-line-or-history'
  'down-line-or-history'
  'accept-line'
  'copy-earlier-word'
  'menu-select'
)

# History substring search configuration
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND=0
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND=0
HISTORY_SUBSTRING_SEARCH_PREFIXED=1
