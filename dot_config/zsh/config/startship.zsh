#!/usr/bin/env zsh

export STARSHIP_THEME="pure"

if [[ "$TERM_PROGRAM" == "tmux" ]]; then
  STARSHIP_THEME="tmux"
fi

if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  STARSHIP_THEME="default"
fi

export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/$STARSHIP_THEME.toml"

export STARSHIP_LOG="error"
