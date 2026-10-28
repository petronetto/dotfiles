#!/usr/bin/env zsh

# Editor configuration
export EDITOR='vim'

# bat - use terminal colors
export BAT_THEME="ansi"

# PATH additions
if [[ "$OSTYPE" == darwin* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
  export PATH="$HOME/.composer/vendor/bin:$PATH"
else
  typeset -gU path
  path=("$HOME/.local/bin" $path)
  [[ ! -d "$HOME/.composer/vendor/bin" ]] || path=("$HOME/.composer/vendor/bin" $path)
fi

# Plans
export PLAN_BACKEND='obsidian'

# Completion options
setopt MENU_COMPLETE        # Automatically highlight first element of completion menu
setopt AUTO_LIST            # Automatically list choices on ambiguous completion
setopt COMPLETE_IN_WORD     # Complete from both ends of a word

# Disable annoying beeping
unsetopt BEEP
