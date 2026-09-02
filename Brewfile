# =============================================================================
# Homebrew Bundle file
# https://github.com/Homebrew/brew/blob/main/docs/Brew-Bundle-and-Brewfile.md
# =============================================================================
#
# Consumed by: run_onchange_after_install-packages.sh.tmpl (scripts/install-packages)
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
brew "chezmoi"      # manage your dotfiles across multiple machines

# --- Version control & hosting CLIs ---
brew "git"
brew "git-delta"    # Syntax-highlighting for git and diff output
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
brew "todoist-cli"  # command-line client for Todoist

# --- Cloud & API CLIs ---
brew "ansible"      # automation & provisioning
brew "awscli"       # AWS CLI v2

# --- AI coding agents & LLM tooling ---
tap "jundot/omlx", "https://github.com/jundot/omlx"
brew "omlx"          # local LLM inference on Apple Silicon (jundot/omlx tap)
brew "pi-coding-agent"
brew "agent-browser"
brew "rtk"          # LLM token-saving proxy (rtk-ai.app)

# --- Media ---
brew "ffmpeg"         # multimedia processing (transcode, extract, etc.)
brew "yt-dlp"         # YouTube / streaming video downloader
brew "openai-whisper" # speech-to-text transcription (OpenAI Whisper)
brew "pocket-tts"     # text-to-speech synthesis

# --- System monitoring ---
brew "btop"           # resource monitor (htop/btop++)

# --- Languages & runtimes ---
brew "rust"
brew "go"
brew "node"
brew "python"
brew "php"
brew "lua"
brew "luarocks"
brew "sqlite"

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
cask "zed"                  # Zed editor

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
cask "ollama-app"

# --- Productivity ---
cask "obsidian"
cask "todoist-app"

# --- Utilities ---
cask "rectangle"            # window management & snapping
cask "maccy"                # clipboard manager
cask "vorssaint"           # menu bar system utilities

# --- Containers ---
cask "docker-desktop"

# --- Fonts (Nerd Fonts — terminal icons & Powerline glyphs) ---
cask "font-fira-code-nerd-font"
cask "font-caskaydia-cove-nerd-font"  # Cascadia Code
cask "font-jetbrains-mono-nerd-font"
