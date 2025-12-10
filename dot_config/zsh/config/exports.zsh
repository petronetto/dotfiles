#!/usr/bin/env zsh

# Editor configuration
export EDITOR='vim'

# 1Password SSH agent
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

# Tool-specific data directories
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"
export BUN_INSTALL="$HOME/.bun"

# PATH additions
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="$BUN_INSTALL/bin:$PATH"