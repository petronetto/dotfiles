#!/usr/bin/env zsh

# TPM (Tmux Plugin Manager) setup
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
TPM_DIR="${XDG_DATA_HOME}/tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

# Check if TPM is installed, install if not
if [[ ! -d "${TPM_DIR}" ]]; then
  echo "TPM not found. Installing..."
  mkdir -p "$(dirname "${TPM_DIR}")"
  git clone "${TPM_REPO}" "${TPM_DIR}"
  echo "TPM installed successfully. Run 'tmux source ~/.tmux.conf' and press prefix + I to install plugins."
fi
