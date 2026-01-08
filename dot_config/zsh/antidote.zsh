#!/usr/bin/env zsh

# Antidote plugin manager setup
ANTIDOTE_HOME="${ZDOTDIR:-$HOME}/.antidote"

# Clone antidote if it doesn't exist
[[ -d "$ANTIDOTE_HOME" ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_HOME"

# Source antidote
source "$ANTIDOTE_HOME/antidote.zsh"

# Set plugins file location
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"

# Generate static plugin file
antidote bundle <<EOBUNDLES >|"$zsh_plugins"
zdharma-continuum/fast-syntax-highlighting kind:defer
zsh-users/zsh-completions kind:fpath path:src
zsh-users/zsh-autosuggestions kind:defer
zsh-users/zsh-history-substring-search
MichaelAquilina/zsh-you-should-use
EOBUNDLES

# Load plugins
source "$zsh_plugins"
