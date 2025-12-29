#!/usr/bin/env zsh

# Create XDG Base Directory Specification directories
# These directories are defined in ~/.config/zsh/.zshenv

echo "Creating XDG Base Directory Specification directories..."

# XDG directories
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.cache"
mkdir -p "$HOME/.cache/run"

# ZSH configuration directory
mkdir -p "$HOME/.config/zsh"

echo "✓ XDG directories created successfully"
