#!/bin/bash
# Bootstrap macOS or Ubuntu 26.04 AMD64 before any Zsh lifecycle scripts run.
# Supports Bash 3.2 and invocation through standard input.

set -Eeuo pipefail

stage="argument validation"
target_user=""
repo="petronetto"
branch=""
source_dir=""
profile=""
explicit_repo=false

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

on_error() {
  local status=$?
  printf 'Error: bootstrap failed during %s (exit %s).\n' "$stage" "$status" >&2
  exit "$status"
}
trap on_error ERR

usage() {
  printf '%s\n' \
    'Usage: bash bootstrap.sh [options]' \
    '  --repo URL       Git repository URL (default: petronetto/dotfiles)' \
    '  --branch NAME    Required source branch, with no fallback' \
    '  --source DIR     Existing local source; conflicts with --repo/--branch' \
    '  --user NAME      Existing non-root target account (required as root)' \
    '  --profile NAME   workstation or test-container (persisted in chezmoi data)' \
    '  --help           Show this help without making changes'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --user|--repo|--branch|--source|--profile)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || fail "$1 requires a value"
      case "$1" in
        --user) target_user=$2 ;;
        --repo) repo=$2; explicit_repo=true ;;
        --branch) branch=$2 ;;
        --source) source_dir=$2 ;;
        --profile) profile=$2 ;;
      esac
      shift 2
      ;;
    *) fail "Unknown option: $1" ;;
  esac
done

case "$profile" in
  ""|workstation|test-container) ;;
  *) fail "--profile must be workstation or test-container" ;;
esac

if [[ -n "$source_dir" ]]; then
  [[ "$explicit_repo" == false && -z "$branch" ]] ||
    fail "--source conflicts with --repo and --branch"
  [[ -d "$source_dir" ]] || fail "Local source directory does not exist: $source_dir"
  source_dir=$(cd "$source_dir" && pwd -P)
fi

select_platform() {
  stage="platform detection"
  platform=$(uname -s)
  case "$platform" in
    Darwin) return ;;
    Linux)
      [[ -r /etc/os-release ]] || fail "Unsupported Linux: Ubuntu 26.04 AMD64 is required"
      # shellcheck disable=SC1091
      . /etc/os-release
      [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]] ||
        fail "Unsupported Linux ${ID:-unknown} ${VERSION_ID:-unknown}: Ubuntu 26.04 AMD64 is required"
      [[ $(uname -m) == x86_64 ]] || fail "Unsupported architecture: Ubuntu requires AMD64"
      ;;
    *) fail "Unsupported operating system: $platform" ;;
  esac
}

select_user() {
  stage="target-user validation"
  invoking_uid=$(id -u)
  if [[ "$invoking_uid" != 0 ]]; then
    local current_user
    current_user=$(id -un)
    [[ -z "$target_user" || "$target_user" == "$current_user" ]] ||
      fail "A normal user cannot select a different --user"
    target_user=$current_user
    target_home=$HOME
    return
  fi

  [[ -n "$target_user" && "$target_user" != -* ]] ||
    fail "Root must specify an existing non-root --user"
  [[ "$platform" == Linux ]] || fail "Run macOS bootstrap as a non-root user"
  local target_uid account
  target_uid=$(id -u "$target_user") || fail "Unknown --user: $target_user"
  [[ "$target_uid" != 0 ]] || fail "--user must be non-root"
  account=$(getent passwd "$target_user") || fail "Cannot resolve --user: $target_user"
  IFS=: read -r _ _ _ _ _ target_home _ <<< "$account"
  [[ "$target_home" == /* && -d "$target_home" && "$target_home" != / ]] ||
    fail "Target user must have an existing absolute home directory"
}

as_root() {
  if [[ "$invoking_uid" == 0 ]]; then
    "$@"
    return
  fi
  sudo -- "$@"
}

as_user() {
  if [[ "$invoking_uid" != 0 ]]; then
    "$@"
    return
  fi
  sudo -H -u "$target_user" -- env \
    HOME="$target_home" USER="$target_user" LOGNAME="$target_user" \
    XDG_CONFIG_HOME="$target_home/.config" XDG_DATA_HOME="$target_home/.local/share" \
    XDG_CACHE_HOME="$target_home/.cache" PATH="$target_home/.local/bin:$PATH" "$@"
}

prepare_ubuntu() {
  stage="Ubuntu sudo elevation"
  if [[ "$invoking_uid" != 0 ]]; then
    command -v sudo >/dev/null || fail "sudo is required for a normal-user bootstrap"
    sudo -v || fail "sudo elevation failed; no packages were installed"
  fi

  stage="Ubuntu prerequisite packages"
  as_root apt-get update
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo ca-certificates curl git gnupg tar libarchive-tools 7zip unzip xz-utils locales jq zsh
  stage="Ubuntu locale generation"
  as_root locale-gen en_US.UTF-8

  stage="Ubuntu chezmoi download/install"
  # The target shell must expand HOME, not the root invoking shell.
  # shellcheck disable=SC2016
  as_user sh -eu -c '
    export PATH="$HOME/.local/bin:$PATH"
    if command -v chezmoi >/dev/null 2>&1; then exit 0; fi
    installer=$(mktemp)
    trap '\''rm -f "$installer"'\'' EXIT
    curl -fsSL https://get.chezmoi.io -o "$installer"
    sh "$installer" -b "$HOME/.local/bin"
    test -x "$HOME/.local/bin/chezmoi"
  '
}

prepare_macos() {
  stage="Xcode Command Line Tools"
  if ! xcode-select -p >/dev/null 2>&1; then
    local placeholder package elapsed
    placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$placeholder"
    package=$(softwareupdate -l 2>/dev/null | grep '\*.*Command Line' | tail -n 1 | sed 's/^[^C]* //' || true)
    rm -f "$placeholder"
    if [[ -n "$package" ]]; then
      sudo softwareupdate -i "$package" --verbose
    else
      printf 'No Command Line Tools package found; opening the GUI installer.\n' >&2
      xcode-select --install
    fi
    elapsed=0
    until xcode-select -p >/dev/null 2>&1 || (( elapsed >= 600 )); do
      sleep 5
      elapsed=$((elapsed + 5))
    done
    xcode-select -p >/dev/null 2>&1 || fail "Command Line Tools unavailable after 10 minutes"
  fi

  stage="Homebrew installation"
  if ! command -v brew >/dev/null 2>&1; then
    local installer
    installer=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    NONINTERACTIVE=1 /bin/bash "$installer"
    rm -f "$installer"
  fi
  if [[ $(uname -m) == arm64 && -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  stage="macOS chezmoi installation"
  if ! command -v chezmoi >/dev/null 2>&1; then
    brew install chezmoi
  fi
}

run_chezmoi() {
  as_user env DOTFILES_PROFILE="$profile" chezmoi "$@"
}

initialize_dotfiles() {
  local args=(init)
  local init_apply=(init --apply)
  local apply=(apply)
  if [[ "$platform" == Darwin ]]; then
    init_apply+=(--keep-going)
    apply+=(--keep-going)
  fi

  if [[ -n "$source_dir" ]]; then
    run_chezmoi --source "$source_dir" "${init_apply[@]}"
    return
  fi
  if [[ -z "$branch" && "$explicit_repo" == false ]]; then
    run_chezmoi "${init_apply[@]}" "$repo"
    return
  fi

  [[ -z "$branch" ]] || args+=(--branch "$branch")
  [[ "$explicit_repo" == false ]] || args+=(--guess-repo-url=false)
  # Init does not switch existing checkouts. Verify selection before applying.
  run_chezmoi "${args[@]}" "$repo"
  if [[ -n "$branch" ]]; then
    local actual_branch
    actual_branch=$(run_chezmoi git -- rev-parse --abbrev-ref HEAD)
    [[ "$actual_branch" == "$branch" ]] ||
      fail "Requested branch $branch, but source is on $actual_branch; select it explicitly before retrying"
  fi
  if [[ "$explicit_repo" == true ]]; then
    local actual_repo
    actual_repo=$(run_chezmoi git -- remote get-url origin)
    [[ "$actual_repo" == "$repo" ]] || fail "Existing source repository differs from --repo; refusing apply"
  fi
  run_chezmoi "${apply[@]}"
}

select_platform
select_user
if [[ "$platform" == Darwin ]]; then
  prepare_macos
else
  prepare_ubuntu
fi

stage="chezmoi initialization and apply"
export PATH="$target_home/.local/bin:$PATH"
initialize_dotfiles
printf 'Bootstrap complete for %s.\n' "$target_user"
