#!/usr/bin/env zsh
set -euo pipefail

(( EUID != 0 )) || { print -u2 'Smoke checks require the non-root tester account'; exit 1; }
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export PATH="$HOME/.local/bin:$XDG_DATA_HOME/mise/shims:$PATH"
readonly source_dir="$HOME/.local/share/chezmoi"
readonly state_dir="$XDG_STATE_HOME/dotfiles/ubuntu-test"
mkdir -p "$state_dir"
umask 077
printf '%s\n' '{"schema":1,"status":"failed","errors":["smoke preflight did not finish"],"results":[]}' > "$state_dir/report.json"
chezmoi --source "$source_dir" execute-template '{{ .ubuntu | toJson }}' > "$state_dir/catalog.json"
exec python3 "$source_dir/scripts/ubuntu-smoke.py" \
  --catalog "$state_dir/catalog.json" \
  --registry "$source_dir/tests/ubuntu/smoke/registry.json" \
  --manifest /opt/dotfiles-fixture/manifest.json \
  --versions "$XDG_STATE_HOME/dotfiles/ubuntu-packages.json" \
  --report "$state_dir/report.json" "$@"
