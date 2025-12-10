#!/usr/bin/env zsh

#---------------------------------------------------------------------------------------------------------------
# Editor
#---------------------------------------------------------------------------------------------------------------
alias vim='nvim'

#---------------------------------------------------------------------------------------------------------------
# Navigation & Utils
#---------------------------------------------------------------------------------------------------------------
alias ..='cd ..'
alias cls="clear"
alias reload='exec "$SHELL" -l'

# Modern replacements
alias cat="bat"     # https://github.com/sharkdp/bat
alias cd="z"        # replace cd with Zoxide command - https://github.com/ajeetdsouza/zoxide

# ls with lsd https://github.com/lsd-rs/lsd
alias ls="lsd"
alias la="ls -a"
alias ll="ls -ll"

# File operations
alias tailf="tail -f"
alias pwd="pwd | tee >(pbcopy)"
alias prev="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"

#---------------------------------------------------------------------------------------------------------------
# Global Aliases for piping
#---------------------------------------------------------------------------------------------------------------
alias -g N="1>/dev/null 2>/dev/null"          # No Output
alias -g B="1>/dev/null 2>/dev/null &"        # Background
alias -g A="2>&1"                             # All (merge stdout/err)
alias -g T="| tee -a /dev/stderr"             # Tee to stderr
alias -g S="| sort | uniq"                    # Sort
alias -g U="| sort | uniq -c | sort -nr"      # Count
alias -g UU="| sort | uniq -c | sort -n | sed -E 's/^ +[0-9]+ //g'" # No Number
alias -g L="| awk '{ print length, $0 }' | sort -n | uniq | cut -d' ' -f2" # Sort by Length