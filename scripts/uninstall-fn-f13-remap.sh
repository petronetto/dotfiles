#!/usr/bin/env zsh

# Manual, local debug script: fully revert the fn -> F13 remap installed by
# run_once_after_remap-fn-to-f13.sh.tmpl.
#
# Unloads and removes the LaunchAgent, then clears the HID UserKeyMapping so
# fn goes back to its default behavior (idempotent: safe to re-run).
#
# Usage: scripts/uninstall-fn-f13-remap.sh

set -uo pipefail

LAUNCH_AGENT_LABEL="com.petronetto.fn2f13remap"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

echo "Reverting fn -> F13 remap..."

if launchctl print "gui/$(id -u)/${LAUNCH_AGENT_LABEL}" &>/dev/null; then
  echo "Unloading LaunchAgent..."
  launchctl bootout "gui/$(id -u)/${LAUNCH_AGENT_LABEL}"
else
  echo "LaunchAgent is not loaded"
fi

if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
  echo "Removing $LAUNCH_AGENT_PLIST..."
  rm -f "$LAUNCH_AGENT_PLIST"
else
  echo "LaunchAgent plist already removed"
fi

echo "Clearing HID key mapping..."
hidutil property --set '{"UserKeyMapping":[]}' >/dev/null

echo "fn -> F13 remap fully reverted for this session (no LaunchAgent left to re-apply it on next login)"
