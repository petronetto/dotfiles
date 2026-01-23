#!/usr/bin/env zsh

# Zoxide data directory
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"

# Zoxide initialization (installed via zinit)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi
