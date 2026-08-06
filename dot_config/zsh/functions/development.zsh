#!/usr/bin/env zsh

# Edit zsh configuration
function config() {
  nvim "$ZDOTDIR"
}

# Composer (Docker-based)
function comp() {
  local COMPOSER_VERSION="${COMPOSER_VERSION:-2.9.3}"

  docker run --rm --interactive --tty \
    --volume $(pwd):/app \
    --volume ${COMPOSER_HOME:-$HOME/.composer}:/tmp \
    --user $(id -u):$(id -g) \
    composer:$COMPOSER_VERSION "$@"
}

# Composer with ignore platform requirements
function compi() {
  comp "$@" --ignore-platform-reqs
}

# Load environment variables from file
function loadenv() {
  local file="${1:-.env}"

  if [[ -f "$file" ]]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ ! "$line" =~ ^# && "$line" =~ ^[[:alnum:]_]+=.+ ]]; then
        export "$line"
      fi
    done <"$file"
  fi
}

# Multi-platform package installer
function install() {
  PACKAGE=$1

  if [ -z "$PACKAGE" ]; then
    echo "Usage: install <package_name>"
    return 1
  fi

  # Identifying the platform
  OS="$(uname)"
  if [ "$OS" = "Darwin" ]; then
    # macOS
    echo "Detected macOS. Installing with brew..."
    brew install $PACKAGE
  elif [ "$OS" = "Linux" ]; then
    # Assuming Ubuntu/Debian. Additional checks could be implemented for other distros.
    echo "Detected Linux. Checking for Ubuntu/Debian..."
    if grep -qEi "(debian|buntu)" /etc/*release; then
      echo "Detected Ubuntu/Debian. Installing with apt..."
      sudo apt update && sudo apt install -y $PACKAGE
    else
      echo "Unsupported Linux distribution. Please install $PACKAGE manually."
    fi
  else
    echo "Unsupported OS. Please install $PACKAGE manually."
  fi
}

# Generate a CSR and private key, printing both to stdout by default.
function gencsr() {
  local only_csr=false only_key=false
  local -a pos_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only-csr|-c) only_csr=true; shift ;;
      --only-key|-k) only_key=true; shift ;;
      --) shift; pos_args+=("$@"); break ;;
      -*) echo "Unknown option: $1" >&2; return 1 ;;
      *) pos_args+=("$1"); shift ;;
    esac
  done

  local domain="${pos_args[1]}"
  if [[ -z "$domain" ]]; then
    echo "Usage: gencsr <domain> [country] [state] [city] [org] [org-unit] [--only-csr|-c] [--only-key|-k]" >&2
    return 1
  fi

  local country="${pos_args[2]:-US}"
  local state="${pos_args[3]:-}"
  local city="${pos_args[4]:-}"
  local org="${pos_args[5]:-}"
  local org_unit="${pos_args[6]:-}"

  local key_file="/tmp/${domain}.key"
  local csr_file="/tmp/${domain}.csr"

  local subj="/CN=${domain}"
  [[ -n "$country"  ]] && subj="/C=${country}${subj}"
  [[ -n "$state"    ]] && subj="${subj}/ST=${state}"
  [[ -n "$city"     ]] && subj="${subj}/L=${city}"
  [[ -n "$org"      ]] && subj="${subj}/O=${org}"
  [[ -n "$org_unit" ]] && subj="${subj}/OU=${org_unit}"

  openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$key_file" \
    -out "$csr_file" \
    -subj "$subj" 2>/dev/null || { echo "Error: failed to generate CSR" >&2; return 1 }

  if $only_key; then
    cat "$key_file"
  elif $only_csr; then
    cat "$csr_file"
  else
    cat "$key_file" "$csr_file"
  fi

  rm -f "$key_file" "$csr_file"
}
