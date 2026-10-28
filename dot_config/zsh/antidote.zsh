#!/usr/bin/env zsh

# Antidote plugin manager setup
# Antidote and its plugins are primed by provisioning; startup never downloads them.
ANTIDOTE_HOME="${ZDOTDIR:-$HOME}/.antidote"

# Plugin list and generated static load file
zsh_plugins_txt="${ZDOTDIR:-$HOME}/zsh_plugins.txt"
zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"

# Only regenerate the static plugin file when the plugin list has changed,
# so antidote isn't invoked (and plugins re-bundled) on every shell startup.
if [[ -f "$ANTIDOTE_HOME/antidote.zsh" ]] && [[ ! "$zsh_plugins" -nt "$zsh_plugins_txt" ]]; then
  source "$ANTIDOTE_HOME/antidote.zsh"
  antidote bundle <"$zsh_plugins_txt" >|"$zsh_plugins"
fi

# Load plugins
[[ -f "$zsh_plugins" ]] && source "$zsh_plugins"
