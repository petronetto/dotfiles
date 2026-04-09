#!/usr/bin/env zsh

# Edit zsh configuration
function config() {
  nvim "$ZDOTDIR"
}

# Open PhpStorm with arguments
function phpstorm() {
  open -na "PhpStorm.app" --args "$@"
}

# Composer (Docker-based)
function comp() {
  $COMPOSER_VERSION=${COMPOSER_VERSION:-"2.9.3"}

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

# Generate a Certificate Signing Request (CSR) and private key in /tmp
function gencsr() {
  local domain="${1}"

  if [[ -z "$domain" ]]; then
    echo "Usage: gencsr <domain> [country] [state] [city] [org] [org-unit]"
    return 1
  fi

  local country="${2:-US}"
  local state="${3:-}"
  local city="${4:-}"
  local org="${5:-}"
  local org_unit="${6:-}"

  local outdir="/tmp/csr-${domain}"
  local key_file="${outdir}/${domain}.key"
  local csr_file="${outdir}/${domain}.csr"

  mkdir -p "$outdir"

  local subj="/CN=${domain}"
  [[ -n "$country"  ]] && subj="/C=${country}${subj}"
  [[ -n "$state"    ]] && subj="${subj}/ST=${state}"
  [[ -n "$city"     ]] && subj="${subj}/L=${city}"
  [[ -n "$org"      ]] && subj="${subj}/O=${org}"
  [[ -n "$org_unit" ]] && subj="${subj}/OU=${org_unit}"

  openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$key_file" \
    -out "$csr_file" \
    -subj "$subj" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo "CSR generated successfully:"
    echo "  Private key : ${key_file}"
    echo "  CSR         : ${csr_file}"
    echo ""
    echo "CSR details:"
    openssl req -noout -text -in "$csr_file" | grep -E "Subject:|Public-Key:"
  else
    echo "Error: failed to generate CSR" >&2
    return 1
  fi
}

# Get system architecture (adapted from rustup-init.sh)
function get_architecture() {
  local _ostype _cputype _arch
  _ostype="$(uname -s)"
  _cputype="$(uname -m)"

  if [ "$_ostype" = Darwin ] && [ "$_cputype" = i386 ]; then
    # Darwin `uname -m` lies
    if sysctl hw.optional.x86_64 | grep -q ': 1'; then
      _cputype=x86_64
    fi
  fi

  case "$_ostype" in
  Linux) _ostype=unknown-linux-gnu ;;
  Darwin) _ostype=apple-darwin ;;
  MINGW* | MSYS* | CYGWIN* | Windows_NT) _ostype=pc-windows-gnu ;;
  *) err "unrecognized OS type: $_ostype" ;;
  esac

  case "$_cputype" in
  i386 | i486 | i686 | i786 | x86) _cputype=i686 ;;
  xscale | arm | armv6l | armv7l | armv8l) _cputype=arm ;;
  aarch64 | arm64) _cputype=aarch64 ;;
  x86_64 | x86-64 | x64 | amd64) _cputype=x86_64 ;;
  *) err "unknown CPU type: $_cputype" ;;
  esac

  _arch="${_cputype}-${_ostype}"
  RETVAL="$_arch"
  echo "$RETVAL"
}
