#!/usr/bin/env zsh

# Docker container rebuild
function dc-rebuild() {
  local color_red=$(tput setaf 1)
  local color_green=$(tput setaf 2)
  local color_reset=$(tput sgr0)
  
  if [[ $1 != "" ]]; then
    docker compose up -d --force-recreate --no-deps --build "$1"
  else
    print "${color_red}ERROR!${color_reset} ${color_green}You must provide the contaner name${color_reset}"
  fi
}

# Execute command in Docker container
function docker-exec() {
  local container=$1
  local color_red=$(tput setaf 1)
  local color_green=$(tput setaf 2)
  local color_reset=$(tput sgr0)

  if [[ -z $container ]]; then
    print "${color_red}ERROR!${color_reset} ${color_green}You must provide the container name${color_reset}"
    return 1
  fi

  local container_id=$(docker ps -f name=$container --quiet | head -n 1)
  
  if [[ -z $container_id ]]; then
    print "${color_red}ERROR!${color_reset} No running container found with name: ${color_green}$container${color_reset}"
    return 1
  fi

  shift
  local command=("${@:-sh}")  # Use remaining args, or 'sh' if none

  docker exec -it "$container_id" "${command[@]}"
}
