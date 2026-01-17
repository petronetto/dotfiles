#!/usr/bin/env bash

# Grab global variable for showing datetime widget, only hide if explicitly disabled
SHOW_DATETIME=$(tmux show-option -gv @gruvbox-tmux_show_time 2>/dev/null)
if [[ $SHOW_DATETIME == "0" ]]; then
  exit 0
fi

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

# Assign values based on user config
time_format=$(tmux show-option -gv @gruvbox-tmux_time_format 2>/dev/null)

TIME=""

case "$time_format" in
    "12H")
        TIME=$(date "+%I:%M %p")
        ;;
    "hide")
        TIME=""
        ;;
    *)
        TIME=$(date "+%H:%M")
        ;;
esac

separator="▒"

echo "$RESET#[fg=${THEME[purple]},bg=${THEME[black]}]$separator 󰥔 $TIME "
