#!/usr/bin/env zsh

#---------------------------------------------------------------------------------------------------------------
# Docker
#---------------------------------------------------------------------------------------------------------------
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
alias docker-rm-net='docker network rm $(docker network ls -q)'
alias docker-rm-vol='docker volume rm $(docker volume ls -q)'
alias docker-clean='docker system prune --all -f'
alias docker-clean-all='docker system prune --all -f && docker volume rm -f $(docker volume ls -q) && docker network rm -f $(docker network ls -q)'
alias dcu='docker context use'
alias dcd='docker context use default'