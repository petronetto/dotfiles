#!/usr/bin/env zsh

# Pi (pi-coding-agent) configuration
# Ref: https://pi.dev/docs/latest/usage#environment-variables

# Config directory
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi"

# Sessions
export PI_CODING_AGENT_SESSION_DIR="$XDG_DATA_HOME/pi/sessions"

# Privacy
export PI_TELEMETRY=0
