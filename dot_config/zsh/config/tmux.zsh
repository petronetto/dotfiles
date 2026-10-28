#!/usr/bin/env zsh

# TPM (Tmux Plugin Manager) setup
# TPM is primed by provisioning; startup never downloads plugins.
# tmux.conf loads TPM from $HOME/.local/share/tmux/plugins/tpm when present.
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
TPM_DIR="${XDG_DATA_HOME}/tmux/plugins/tpm"

[[ -d "${TPM_DIR}" ]] || print "⚠️ TPM not primed; run provisioning to install." >&2
