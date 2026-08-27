#!/usr/bin/env bash
# Transparently rewrites Bash commands to their rtk equivalent for token savings,
# per the global AGENTS.md instruction to prefix supported commands with rtk.
# Delegates to `rtk rewrite`, the same contract dot_config/pi/extensions/rtk.ts uses:
#   0/3 + stdout  rewrite found -> mutate command
#   1             no rtk equivalent -> pass through unchanged
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

[ -z "$cmd" ] && exit 0
[[ "$cmd" == rtk\ * ]] && exit 0
[ "${RTK_DISABLED:-}" = "1" ] && exit 0
command -v rtk >/dev/null 2>&1 || exit 0

set +e
rewritten=$(rtk rewrite "$cmd" 2>/dev/null)
code=$?
set -e

if { [ "$code" -eq 0 ] || [ "$code" -eq 3 ]; } && [ -n "$rewritten" ] && [ "$rewritten" != "$cmd" ]; then
  jq -n --arg cmd "$rewritten" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: {command: $cmd}}}'
fi

exit 0
