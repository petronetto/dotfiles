#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$HOME/.config/tmux/scripts"

source "$SCRIPTS_PATH/themes.sh" || {
    echo "Error: Failed to source themes.sh" >&2
    exit 1
}

tmux set -g status-left-length 80
tmux set -g status-right-length 150

tmux set -g mode-style "fg=${THEME[background]},bg=${THEME[foreground]},reverse"

tmux set -g message-style "bg=${THEME[bblue]},fg=${THEME[background]},bold"
tmux set -g message-command-style "fg=${THEME[white]},bg=${THEME[black]},bold"

tmux set -g pane-border-style "fg=${THEME[bblack]}"
tmux set -g pane-active-border-style "fg=${THEME[white]},bold"
tmux set -g pane-border-status off

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

terminal_icon="$(tmux show-option -gv @gruvbox-tmux_terminal_icon 2>/dev/null || echo '')"
active_terminal_icon="$(tmux show-option -gv @gruvbox-tmux_active_terminal_icon 2>/dev/null || echo '')"

git_status="#($SCRIPTS_PATH/git-status.sh #{pane_current_path})"
wb_git_status=""
window_number="#I "
custom_pane="#P"
zoom_number="#P"
date_and_time="$($SCRIPTS_PATH/datetime-widget.sh)"
battery_status=""

tmux set -g status-left "\
#[fg=${THEME[foreground]},bg=${THEME[red]},bold] \
#{?client_prefix,󰠠 ,󰤂 }\
#[bold,nodim]#S "

tmux set -g window-status-current-format "\
$RESET\
#[fg=${THEME[bgreen]},bg=${THEME[bblack]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon }\
#[fg=${THEME[bpurple]},bold,nodim]\
#W \
#{?window_last_flag, ,}"

tmux set -g window-status-format "\
$RESET\
#[fg=${THEME[foreground]}] \
#{?#{==:#{pane_current_command},ssh},󰣀 ,$terminal_icon }\
${RESET}\
#W \
#[fg=${THEME[yellow]}]\
#{?window_last_flag, ,}"

right_status="\
#[fg=${THEME[ghgreen]},bg=${THEME[black]}]$git_status\
\
\
#[fg=${THEME[ghyellow]},bg=${THEME[black]}]$date_and_time"

tmux set -g status-right "$right_status"

tmux set -g window-status-separator ""
