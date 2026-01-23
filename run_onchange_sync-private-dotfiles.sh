#!/usr/bin/env zsh

# This script clones a private dotfiles repo and syncs all files
# maintaining the directory structure from the repo
# It's designed to be optional - if it fails, installation continues

set -euo pipefail

# Configuration
PRIVATE_REPO_URL="${PRIVATE_DOTFILES_REPO:-git@github.com:petronetto/dotfiles-private.git}"
TEMP_DIR="${TMPDIR:-/tmp}/dotfiles-private-$$"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

cleanup() {
  if [[ -d "${TEMP_DIR}" ]]; then
    log_info "Cleaning up temporary directory..."
    rm -rf "${TEMP_DIR}"
  fi
}

# Ensure cleanup happens on exit
trap cleanup EXIT INT TERM

main() {
  log_info "Starting private dotfiles sync..."

  # Try to clone the private repo
  if ! git clone --depth 1 "${PRIVATE_REPO_URL}" "${TEMP_DIR}" 2>/dev/null; then
    log_warn "Failed to clone private dotfiles repo from ${PRIVATE_REPO_URL}"
    log_warn "This is optional, continuing installation..."
    return 0
  fi

  log_info "Successfully cloned private dotfiles repo"

  # Copy all files maintaining directory structure
  log_info "Syncing private dotfiles to home directory..."

  # Use rsync to copy files, excluding .git directory
  if command -v rsync >/dev/null 2>&1; then
    rsync -av --exclude='.git' "${TEMP_DIR}/" "${HOME}/"
  else
    # Fallback to cp if rsync is not available
    cp -r "${TEMP_DIR}"/.[!.]* "${HOME}/" 2>/dev/null || true
    cp -r "${TEMP_DIR}"/* "${HOME}/" 2>/dev/null || true
  fi

  # Set appropriate permissions
  log_info "Setting permissions..."

  # SSH files should be restrictive
  [[ -d "${HOME}/.ssh/config.d" ]] && chmod 700 "${HOME}/.ssh" && chmod 600 "${HOME}/.ssh/config.d"/*

  # Scripts should be executable
  [[ -d "${HOME}/.local/bin" ]] && chmod +x "${HOME}/.local/bin"/*

  # Zsh files should be readable
  [[ -d "${HOME}/.config/zsh/private" ]] && chmod 644 "${HOME}/.config/zsh/private"/*

  log_info "Private dotfiles sync completed successfully!"
}

# Run main function and catch any errors
if ! main; then
  log_error "An error occurred during private dotfiles sync"
  log_warn "Continuing installation anyway..."
  exit 0
fi

exit 0
