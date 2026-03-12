#!/usr/bin/env zsh

# 1Password SSH agent
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

source_if_exists "$XDG_CONFIG_HOME/op/plugins.sh"
