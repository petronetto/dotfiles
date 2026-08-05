#!/usr/bin/env zsh

# Enable Touch ID for sudo, including inside tmux.
#
# Writes /etc/pam.d/sudo_local — included by the stock /etc/pam.d/sudo and
# preserved across macOS updates — with:
#   - pam_reattach.so: reattaches the process to the user's GUI session so
#     the Touch ID prompt can appear inside tmux (the tmux server detaches
#     from the session's bootstrap namespace)
#   - pam_tid.so: Touch ID authentication
#
# Also removes the pam_tid line a previous version of this script added
# directly to /etc/pam.d/sudo: it is redundant once sudo_local exists, and
# macOS updates wipe it anyway.

set -euo pipefail

echo "Configuring Touch ID for sudo (with tmux support)..."

if ! brew list pam-reattach &>/dev/null; then
  echo "Installing pam-reattach..."
  brew install pam-reattach
fi

# pam_reattach lives outside /usr/lib/pam, so PAM needs its full path
PAM_REATTACH="$(brew --prefix)/lib/pam/pam_reattach.so"
SUDO_LOCAL="/etc/pam.d/sudo_local"

if grep -q "pam_reattach.so" "$SUDO_LOCAL" 2>/dev/null; then
  echo "Touch ID with tmux support is already configured"
else
  echo "Writing $SUDO_LOCAL..."
  sudo tee "$SUDO_LOCAL" >/dev/null <<EOF
# sudo_local: local sudo PAM config, survives macOS updates
auth       optional       $PAM_REATTACH ignore_ssh
auth       sufficient     pam_tid.so
EOF
fi

if grep -q "pam_tid.so" /etc/pam.d/sudo; then
  echo "Removing redundant pam_tid line from /etc/pam.d/sudo..."
  sudo sed -i '' '/pam_tid\.so/d' /etc/pam.d/sudo
fi

echo "Touch ID for sudo is enabled, inside and outside tmux"
