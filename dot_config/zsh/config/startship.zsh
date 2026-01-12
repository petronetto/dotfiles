#!/usr/bin/env zsh

export STARSHIP_THEME="round"

if [[ "$TERM_PROGRAM" == "ghostty" || "$TERM_PROGRAM" == "tmux" ]]; then
  STARSHIP_THEME="default"
fi

export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/$STARSHIP_THEME.toml"

export STARSHIP_LOG="error"
