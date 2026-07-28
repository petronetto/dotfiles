#!/usr/bin/env zsh

# CLI tools initialization
command -v mise &>/dev/null && eval "$(mise activate zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"
