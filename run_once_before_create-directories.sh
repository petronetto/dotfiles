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

# Create /opt/code directory and set ownership to current user
echo "Creating /opt/code directory..."
if [[ ! -d /opt/code ]]; then
  sudo mkdir -p /opt/code
  sudo chown "$USER" /opt/code
  echo "/opt/code created and ownership set to $USER"
else
  echo "/opt/code already exists"
fi

echo "XDG directories created successfully"
