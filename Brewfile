# =============================================================================
# Homebrew Bundle file
# https://github.com/Homebrew/brew/blob/main/docs/Brew-Bundle-and-Brewfile.md
# =============================================================================
#
# Consumed by: run_onchange_after_install-packages.sh.tmpl (scripts/install-packages)
#
# Grouped by category, not by install type:
#   brew "x"  -> formulae (CLI tools, libraries, runtimes)
#   cask "x"  -> GUI applications
# =============================================================================

# --- Core shell & system utilities ---
brew "bash"         # newer Bash (macOS ships 3.2)
brew "curl"         # modern curl (HTTP/2, current SSL)
brew "openssl"      # TLS / crypto libraries
brew "pam-reattach" # Touch ID for sudo inside tmux (used by /etc/pam.d/sudo_local)
brew "chezmoi"      # manage your dotfiles across multiple machines
brew "dockutil"     # scriptable Dock management

# --- Shell prompt & history ---
brew "antidote"     # fast Zsh plugin manager
brew "starship"     # cross-shell prompt
brew "atuin"        # synced, searchable shell history

# --- Terminal, editors & multiplexer ---
brew "neovim"
brew "tmux"
brew "herdr"
cask "ghostty"      # terminal emulator
cask "zed"          # Zed editor

# --- Version control & hosting CLIs ---
brew "git"
brew "git-delta"    # syntax-highlighting for git and diff output
brew "gh"           # GitHub CLI

# --- Modern CLI utilities (replacements / quality of life) ---
brew "bat"          # cat with syntax highlighting
brew "fd"           # find replacement
brew "lsd"          # ls replacement (nerd-font icons)
brew "zoxide"       # cd replacement (frecency-based)
brew "fzf"          # fuzzy finder
brew "ripgrep"      # grep replacement
brew "ast-grep"     # AST-based structural code search (used by agent skills)
brew "procs"        # ps replacement
brew "tlrc"         # community-driven, simplified man pages
brew "jq"           # JSON processor
brew "gum"          # modern CLI prompts & menus
brew "httpie"       # human-friendly HTTP client
brew "todoist-cli"  # command-line client for Todoist

# --- AI coding agents & desktop clients ---
brew "ollama"
brew "pi-coding-agent"
brew "agent-browser"
cask "claude"       # Claude desktop app
cask "claude-code"  # Claude Code CLI
cask "fluidvoice"   # on-device voice dictation with AI enhancement

# --- Security & passwords ---
cask "1password-cli" # `op` CLI for scripting 1Password
cask "1password"

# --- Productivity & communication ---
cask "obsidian"     # notes & knowledge base
cask "todoist-app"  # task manager
cask "slack"        # team communication

# --- Development: languages & runtimes ---
brew "rust"
brew "go"
brew "node"
brew "python"
brew "php"
brew "lua"
brew "luarocks"
brew "sqlite"

# --- Development: language tooling & package managers ---
brew "pyenv"        # Python version manager
brew "pipx"         # install Python CLI apps in isolated envs
brew "composer"     # PHP dependency manager

# --- Development: APIs, containers & local infrastructure ---
brew "dnsmasq"      # local DNS for dev domains
brew "mkcert"       # locally-trusted HTTPS certificates
cask "bruno"        # open-source API client (Postman alternative)
cask "docker-desktop"

# --- Cloud & infrastructure CLIs ---
brew "ansible"      # automation & provisioning
brew "awscli"       # AWS CLI v2

# --- Media (local AI pipelines included) ---
brew "ffmpeg"         # multimedia processing (transcode, extract, etc.)
brew "yt-dlp"         # YouTube / streaming video downloader
brew "openai-whisper" # speech-to-text transcription (OpenAI Whisper)
brew "pocket-tts"     # text-to-speech synthesis

# --- System monitoring & maintenance ---
brew "btop"         # resource monitor (htop/btop++)
brew "mole"         # deep clean and Mac optimization tool

# --- Browsers ---
cask "brave-browser"

# --- GUI utilities ---
cask "rectangle"    # window management & snapping
cask "vorssaint"    # menu bar system utilities

# --- Fonts (Nerd Fonts — terminal icons & Powerline glyphs) ---
cask "font-fira-code-nerd-font"
cask "font-caskaydia-cove-nerd-font"  # Cascadia Code
cask "font-jetbrains-mono-nerd-font"