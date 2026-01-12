#!/usr/bin/env zsh

# TPM (Tmux Plugin Manager) setup
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
TPM_DIR="${XDG_DATA_HOME}/tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

# Check if TPM is installed
if [[ ! -d "${TPM_DIR}" ]]; then
  echo "TPM not found. Installing..."
  mkdir -p "$(dirname "${TPM_DIR}")"
  git clone "${TPM_REPO}" "${TPM_DIR}"
  echo "TPM installed successfully."
fi

# Source TPM if it exists
if [[ -f "${TPM_DIR}/tpm" ]]; then
  # Run TPM
  "${TPM_DIR}/bin/install_plugins"
fi
