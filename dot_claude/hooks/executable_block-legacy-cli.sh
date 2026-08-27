#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

# One-off escape hatch for genuine cases the modern tool can't cover.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`(])[[:space:]]*LEGACY_CLI_OK=1[[:space:]]'; then
  exit 0
fi

boundary='(^|[;&|`(]|\bsudo[[:space:]]+|\bxargs[[:space:]]+|\btime[[:space:]]+|\bnice[[:space:]]+)[[:space:]]*'

block() {
  local name="$1" msg="$2"
  if printf '%s' "$cmd" | grep -Eq "${boundary}${name}\\b"; then
    echo "Blocked by AGENTS.md modern-CLI policy: ${msg}" >&2
    echo "One-off override: prefix the command with LEGACY_CLI_OK=1" >&2
    exit 2
  fi
}

block grep "use 'rg' instead of 'grep'."
block find "use 'fd' instead of 'find'."
block cat  "use 'bat' instead of 'cat'."

exit 0
