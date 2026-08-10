#!/usr/bin/env zsh

#------------------------------------------------------------
# Docker
#------------------------------------------------------------
alias dc='docker compose'
alias dup='docker compose up -d'
alias dcs='docker compose stop'
alias de='docker-exec'
alias docker-init='open --background -a Docker'
alias docker-ip='docker inspect -f "{{.Name}} - {{.NetworkSettings.IPAddress }}" $(docker ps -aq)'
alias docker-rm='docker stop $(docker ps -aq) && docker rm $(docker ps -aq)'
alias docker-rm-stoped='docker stop $(docker ps -aq -f status=exited) && docker rm $(docker ps -aq -f status=exited)'
alias docker-start-all='docker start $(docker ps -aq)'
alias docker-restart='docker restart $(docker ps -aq)'
alias docker-stop-all='docker stop $(docker ps -aq)'
alias dsa='docker-stop-all'
alias docker-rmi='docker rmi $(docker images -aq) -f'
alias docker-rmn='docker network rm -f $(docker network ls -q)'
alias docker-rmv='docker volume rm -f $(docker volume ls -q)'
alias docker-clean='docker system prune --all -f'
alias docker-clean-all='docker-clean && docker-rmv && docker-rmn && docker-rmi'
alias dps="docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}'"
alias dcu='docker context use'
alias dcd='docker context use default'

#------------------------------------------------------------
# Editor
#------------------------------------------------------------
alias vim='nvim'

#------------------------------------------------------------
# Navigation & Utils
#------------------------------------------------------------
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
alias lla="ls -lla"

# File operations
alias tailf="tail -f"
alias pwd="pwd | tee >(pbcopy)"
alias prev="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"

#------------------------------------------------------------
# Global Aliases for piping
#------------------------------------------------------------
alias -g N="1>/dev/null 2>/dev/null"          # No Output
alias -g B="1>/dev/null 2>/dev/null &"        # Background
alias -g A="2>&1"                             # All (merge stdout/err)
alias -g T="| tee -a /dev/stderr"             # Tee to stderr
alias -g S="| sort | uniq"                    # Sort
alias -g U="| sort | uniq -c | sort -nr"      # Count
alias -g UU="| sort | uniq -c | sort -n | sed -E 's/^ +[0-9]+ //g'" # No Number
alias -g L="| awk '{ print length, $0 }' | sort -n | uniq | cut -d' ' -f2" # Sort by Length

#------------------------------------------------------------
# Git
#------------------------------------------------------------
alias clone="git clone"
alias gmain="git checkout main"
alias gdev="git checkout dev"
alias gm="gmain"
alias gd="gdev"
alias gcb="git branch -vv | awk '/: gone\]/ {print \$1}' | xargs git branch -f -d"
alias gfa="git fetch --all"
alias gpull="git fetch -p --all && git pull"
alias gp="gpull"
alias gpush="git push 2>&1 | grep \"git push\" | sh"
alias gph="gpush"
alias ggraph="git log --graph --oneline --decorate --all"

#------------------------------------------------------------
# Python
#------------------------------------------------------------
alias python='python3'
alias py='python'
alias pip='pip3'

#------------------------------------------------------------
# tmux
#------------------------------------------------------------
alias t="tmux"
alias ta="tmux_attach_or_create"
alias tn="tmux_new_session"
alias tl="tmux ls"
alias tk="tmux kill-session -t"
alias tks="tmux kill-server"
