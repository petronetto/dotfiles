#!/usr/bin/env bash
# Tmux Theme Configuration

# Gruvbox Hard - hardcoded hex colors
declare -A GRUVBOX=(
  [background]="#1b1b1b"
  [foreground]="#fbf1c7"
  [black]="#1b1b1b"
  [blue]="#458588"
  [green]="#98971a"
  [purple]="#b16286"
  [red]="#cc241d"
  [yellow]="#d79921"
  [white]="#fbf1c7"
  [bblack]="#282828"
  [bblue]="#83a598"
  [bgreen]="#b8bb26"
  [bpurple]="#d3869b"
  [bred]="#fb4934"
  [bwhite]="#EBDBB2"
  [byellow]="#fabd2f"
  [ghgreen]="#b8bb26"
  [ghyellow]="#fabd2f"
)

# Default - uses terminal's color scheme
declare -A DEFAULT=(
    [background]="default"
    [foreground]="default"
    [black]="colour0"
    [blue]="colour4"
    [green]="colour2"
    [purple]="colour5"
    [red]="colour1"
    [yellow]="colour3"
    [white]="colour15"
    [bblack]="colour0"
    [bblue]="colour12"
    [bgreen]="colour10"
    [bpurple]="colour13"
    [bred]="colour9"
    [bwhite]="colour15"
    [byellow]="colour11"
    [ghgreen]="colour10"
    [ghyellow]="colour11"
)

# Select theme: set @theme in tmux.conf (gruvbox or default)
THEME_NAME=$(tmux show-option -gqv @theme 2>/dev/null)
THEME_NAME=${THEME_NAME:-default}

# Copy selected theme to THEME array
declare -A THEME
if [[ "$THEME_NAME" == "gruvbox" ]]; then
    for key in "${!GRUVBOX[@]}"; do
        THEME[$key]="${GRUVBOX[$key]}"
    done
else
    for key in "${!DEFAULT[@]}"; do
        THEME[$key]="${DEFAULT[$key]}"
    done
fi

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
