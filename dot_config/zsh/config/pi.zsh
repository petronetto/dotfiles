#!/usr/bin/env zsh

# Pi (pi-coding-agent) configuration
# Ref: https://pi.dev/docs/latest/usage#environment-variables

# Config directory: relocate from the default ~/.pi/agent to XDG_CONFIG_HOME.
# Holds settings.json, models.json, keybindings.json, prompts/, themes/,
# extensions config, auth.json, trust.json, run-history.jsonl, sessions/
# (nested per-project tree), and installed npm/git packages. Sessions are kept
# inside the agent dir because Pi's custom session-dir reader is flat and would
# orphan its nested run-N/<cwd-hash>/<uuid>/... layout; relocating the whole
# agent dir preserves it verbatim.
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi"

# PI_PACKAGE_DIR is intentionally left unset. It points to Pi's own bundled
# assets (themes, docs, examples) for Nix/Guix store paths, not user extensions.
# Setting it on macOS/Homebrew would break runtime asset resolution.

# Privacy: disable install/update telemetry and provider attribution headers.
# Mirrors the global opt-out in config/privacy.zsh using Pi's own variable.
export PI_TELEMETRY=0