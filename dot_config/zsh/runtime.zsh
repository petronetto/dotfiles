#!/usr/bin/env zsh

[[ "$OSTYPE" == linux* ]] || return 0

typeset -gU path
path=("$HOME/.local/bin" $path)
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh --shims)"
fi
