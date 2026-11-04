#!/usr/bin/env zsh

# Rust/Cargo environment
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
