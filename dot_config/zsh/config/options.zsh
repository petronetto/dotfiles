#!/usr/bin/env zsh

# Completion options
setopt MENU_COMPLETE        # Automatically highlight first element of completion menu
setopt AUTO_LIST            # Automatically list choices on ambiguous completion
setopt COMPLETE_IN_WORD     # Complete from both ends of a word

# Disable annoying beeping
unsetopt BEEP