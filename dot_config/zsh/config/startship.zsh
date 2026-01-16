#!/usr/bin/env zsh

export STARSHIP_THEME="default"

if [[ "$TERM_PROGRAM" == "tmux" ]]; then
  STARSHIP_THEME="tmux"
fi

export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/$STARSHIP_THEME.toml"

export STARSHIP_LOG="error"
