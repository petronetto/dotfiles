#!/usr/bin/env zsh

# Tools are now managed by zinit in plugins/zinit.zsh
# This file handles tool initialization only

# Zoxide initialization (installed via zinit)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Atuin initialization (install via: curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh)
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
