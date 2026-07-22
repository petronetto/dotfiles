# =============================================================================
# Homebrew Bundle file
# https://github.com/Homebrew/brew/blob/main/docs/Brew-Bundle-and-Brewfile.md
# =============================================================================
#
# Consumed by: run_onchange_darwin-install-packages.sh.tmpl
# =============================================================================

# --------------------------------------------------------------------------
# Formulae (CLI tools, libraries, runtimes) — brew install
# --------------------------------------------------------------------------

# --- Core shell & system utilities ---
brew "bash"         # newer Bash (macOS ships 3.2)
brew "curl"         # modern curl (HTTP/2, current SSL)
brew "openssl"      # TLS / crypto libraries
brew "httpie"       # human-friendly HTTP client

# --- Version control & hosting CLIs ---
brew "git"
brew "gh"           # GitHub CLI
brew "glab"         # GitLab CLI

# --- Editor & terminal multiplexer ---
brew "neovim"
brew "tmux"

# --- Zsh framework & prompt ---
brew "antidote"     # fast Zsh plugin manager
brew "starship"     # cross-shell prompt

# --- Modern CLI utilities (coreutils replacements / quality of life) ---
brew "bat"          # cat with syntax highlighting
brew "fd"           # find replacement
brew "lsd"          # ls replacement (nerd-font icons)
brew "zoxide"       # cd replacement (frecency-based)
brew "fzf"          # fuzzy finder
brew "ripgrep"      # grep replacement
brew "atuin"        # synced, searchable shell history
brew "procs"        # ps replacement
brew "tldr"         # community-driven, simplified man pages

# --- AI coding agents & LLM tooling ---
brew "pi-coding-agent"
brew "agent-browser"
brew "rtk"          # LLM token-saving proxy (rtk-ai.app)

# --- Languages & runtimes ---
brew "rust"
brew "go"
brew "node@24"      # Node.js LTS (linked post-install, see template)
brew "python"
brew "php"
brew "lua"
brew "luarocks"     # Lua package manager

# --- Language tooling & package managers ---
brew "pyenv"        # Python version manager
brew "pipx"         # install Python CLI apps in isolated envs
brew "composer"     # PHP dependency manager
brew "symfony-cli"  # Symfony project scaffolder / local server

# --- Networking & local dev infrastructure ---
brew "dnsmasq"      # local DNS for dev domains
brew "mkcert"       # locally-trusted HTTPS certificates
brew "mole"         # SSH tunnel / port forwarding

# --------------------------------------------------------------------------
# Casks (GUI applications) — brew install --cask
# --------------------------------------------------------------------------

# --- Terminal emulator ---
cask "ghostty"

# --- Editors & IDEs ---
cask "cursor"

# --- Browsers ---
cask "brave-browser"

# --- Communication ---
cask "slack"

# --- Security & passwords ---
cask "1password"
cask "1password-cli"  # `op` CLI for scripting 1Password

# --- API & dev tools ---
cask "bruno"          # open-source API client (Postman alternative)

# --- AI desktop clients ---
cask "claude"
cask "claude-code"

# --- Containers ---
cask "docker-desktop"

# --- Fonts (Nerd Fonts — terminal icons & Powerline glyphs) ---
cask "font-fira-code-nerd-font"
cask "font-caskaydia-cove-nerd-font"  # Cascadia Code
cask "font-jetbrains-mono-nerd-font"

# --------------------------------------------------------------------------
# Mac App Store apps — mas
# --------------------------------------------------------------------------
brew "mas"          # Mac App Store CLI, required for `mas` entries below

mas "Magnet", id: 441258766
mas "Paste", id: 967805235
