#!/bin/bash
#
# One-shot bootstrap for a fresh Mac: installs, in order, the Xcode Command
# Line Tools, Homebrew, and chezmoi, then runs `chezmoi init --apply` to
# provision the rest of the machine from https://github.com/petronetto/dotfiles.
#
# CLT is installed first and non-interactively (via `softwareupdate`, not
# `xcode-select --install`) because Homebrew's own installer will otherwise
# trigger its interactive CLT prompt, which hangs a headless/piped run.
#
#   curl -fsSL https://raw.githubusercontent.com/petronetto/dotfiles/main/bootstrap.sh | bash

set -eufo pipefail

echo "ℹ️ Checking Xcode Command Line Tools..."

if ! xcode-select -p &>/dev/null; then
    echo "ℹ️ Installing Xcode Command Line Tools..."

    # Installed via softwareupdate instead of `xcode-select --install` so this
    # never pops up Apple's GUI installer, which has been unreliable on some
    # older Macs and can hang the whole bootstrap run waiting on a click.
    CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$CLT_PLACEHOLDER"
    CLT_PACKAGE=$(softwareupdate -l 2>/dev/null | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //' || true)
    rm -f "$CLT_PLACEHOLDER"

    if [[ -n "$CLT_PACKAGE" ]]; then
        sudo softwareupdate -i "$CLT_PACKAGE" --verbose
    else
        echo "⚠️ softwareupdate couldn't find Command Line Tools, falling back to the GUI installer" >&2
        xcode-select --install
    fi

    elapsed=0
    until xcode-select -p &>/dev/null || (( elapsed >= 600 )); do
        sleep 5
        elapsed=$(( elapsed + 5 ))
    done

    if xcode-select -p &>/dev/null; then
        echo "✅ Xcode Command Line Tools installed"
    else
        echo "❌ Xcode Command Line Tools still not installed after 10 minutes" >&2
        exit 1
    fi
else
    echo "✅ Xcode Command Line Tools already installed"
fi

echo "ℹ️ Checking Homebrew installation..."

if ! command -v brew &>/dev/null; then
    echo "ℹ️ Installing Homebrew..."
    export NONINTERACTIVE=1
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    echo "✅ Homebrew installed"
else
    echo "✅ Homebrew already installed"
fi

# Ensure Homebrew is in PATH
if [[ $(uname -m) == "arm64" ]] && [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

echo "ℹ️ Checking chezmoi installation..."

if ! command -v chezmoi &>/dev/null; then
    echo "ℹ️ Installing chezmoi..."
    brew install chezmoi
    echo "✅ chezmoi installed"
else
    echo "✅ chezmoi already installed"
fi

echo "ℹ️ Running chezmoi init --apply..."
chezmoi init --apply petronetto
