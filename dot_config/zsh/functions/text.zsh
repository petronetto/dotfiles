#!/usr/bin/env zsh

# Converts text to snake_case
function snake() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g' | sed -E 's/^_+|_+$//g'
}

# Converts text to a URL-friendly slug
function slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g'
}

# Converts text to camelCase
function camel() {
    echo "$1" | sed -E 's/[^a-zA-Z0-9]+/ /g' | awk '{ for (i=1; i<=NF; i++) { $i = (i == 1 ? tolower($i) : toupper(substr($i, 1, 1)) substr($i, 2)) } }1' | tr -d ' '
}