#!/bin/sh
# Install 1Password CLI if not already installed
# This runs via hooks.read-source-state.pre before chezmoi reads the source state

set -e

# Exit immediately if op is already in $PATH
if command -v op >/dev/null 2>&1; then
    exit 0
fi

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
    echo "1Password CLI installation is only supported on macOS"
    exit 0
fi

echo "Installing 1Password CLI..."

# Install Homebrew if not present (required for 1Password CLI)
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew first (required for 1Password CLI)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for current session
    if [ "$(uname -m)" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install 1Password CLI
echo "Installing 1Password CLI via Homebrew..."
brew install --cask 1password-cli

echo "1Password CLI installed successfully"
