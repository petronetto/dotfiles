#!/usr/bin/env zsh

# Antidote plugin manager setup
ANTIDOTE_HOME="${ZDOTDIR:-$HOME}/.antidote"

# Clone antidote if it doesn't exist
[[ -d "$ANTIDOTE_HOME" ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_HOME"

# Plugin list and generated static load file
zsh_plugins_txt="${ZDOTDIR:-$HOME}/zsh_plugins.txt"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"

# Only regenerate the static plugin file when the plugin list has changed,
# so antidote isn't invoked (and plugins re-bundled) on every shell startup.
if [[ ! "$zsh_plugins" -nt "$zsh_plugins_txt" ]]; then
  source "$ANTIDOTE_HOME/antidote.zsh"
  antidote bundle <"$zsh_plugins_txt" >|"$zsh_plugins"
fi

# Load plugins
source "$zsh_plugins"
