#!/usr/bin/env zsh

# Attach to tmux session or create if it doesn't exist
function tmux_attach_or_create() {
  if [ -z "$1" ]; then
    echo "Usage: tmux_attach_or_create <session-name>"
    return 1
  fi

  if tmux has-session -t "$1" 2>/dev/null; then
    tmux attach-session -t "$1"
  else
    tmux new-session -s "$1"
  fi
}

# Create new tmux session
function tmux_new_session() {
  if [ -z "$1" ]; then
    echo "Usage: tmux_new_session <session-name>"
    return 1
  fi
  tmux new-session -s "$1"
}
