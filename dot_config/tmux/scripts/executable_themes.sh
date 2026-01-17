#!/usr/bin/env bash
# Gruvbox Hard Theme

declare -A THEME=(
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

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
