#!/usr/bin/env zsh

#---------------------------------------------------------------------------------------------------------------
# Git
#---------------------------------------------------------------------------------------------------------------
alias clone="git clone"
alias gmain="git checkout main"
alias gm="gmain"
alias gcb="git branch -vv | awk '/: gone\\]/ {print \$1}' | xargs git branch -f -d"
alias gfa="git fetch --all"
alias gpull="git fetch -p --all && git pull"
alias gp="gpull"
alias gpush="git push 2>&1 | grep \"git push\" | sh"
alias gph="gpush"
alias ggraph="git log --graph --oneline --decorate --all"