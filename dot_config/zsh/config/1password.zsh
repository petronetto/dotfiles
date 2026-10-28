#!/usr/bin/env zsh

# 1Password SSH agent
if [[ "$OSTYPE" == darwin* ]]; then
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
else
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

source_if_exists "$XDG_CONFIG_HOME/op/plugins.sh"
