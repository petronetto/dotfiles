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
brew "pam-reattach" # Touch ID for sudo inside tmux (used by /etc/pam.d/sudo_local)

# --- Version control & hosting CLIs ---
brew "git"
brew "gh"           # GitHub CLI

# --- Editor & terminal multiplexer ---
brew "neovim"
brew "tmux"
brew "herdr"

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
brew "tlrc"         # community-driven, simplified man pages
brew "jq"           # JSON processor
brew "gum"          # modern CLI prompts & menus

# --- Cloud & API CLIs ---
brew "ansible"      # automation & provisioning
brew "awscli"       # AWS CLI v2

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

# --- Networking & local dev infrastructure ---
brew "dnsmasq"      # local DNS for dev domains
brew "mkcert"       # locally-trusted HTTPS certificates

# --- macOS utilities & system management ---
brew "dockutil"     # scriptable Dock management
brew "mole"         # deep clean and Mac optimization tool

# --------------------------------------------------------------------------
# Casks (GUI applications) — brew install --cask
# --------------------------------------------------------------------------

# --- Terminal emulator ---
cask "ghostty"

# --- Editors & IDEs ---
cask "visual-studio-code"   # VS Code IDE

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

# --- Productivity ---
cask "obsidian"
cask "todoist-app"

# --- Utilities ---
cask "rectangle"            # window management & snapping
cask "paste"                # clipboard manager

# --- Containers ---
cask "docker-desktop"

# --- Fonts (Nerd Fonts — terminal icons & Powerline glyphs) ---
cask "font-fira-code-nerd-font"
cask "font-caskaydia-cove-nerd-font"  # Cascadia Code
cask "font-jetbrains-mono-nerd-font"
