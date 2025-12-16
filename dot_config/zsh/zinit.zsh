#!/usr/bin/env zsh

# Zinit plugin manager setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# ================================================================================================
# CLI Tools (GitHub Releases)
# ================================================================================================

# Starship prompt
zinit ice from"gh-r" as"command" atload'eval "$(starship init zsh)"'
zinit load starship/starship

# bat (Better Cat)
zinit ice from"gh-r" as"command" mv"bat* -> bat" pick"bat/bat"
zinit load sharkdp/bat

# fd (Fast Directory Finder)
zinit ice from"gh-r" as"command" mv"fd* -> fd" pick"fd/fd"
zinit load sharkdp/fd

# lsd (List Directory Structure)
zinit ice from"gh-r" as"command" mv"**/lsd -> lsd"
zinit load lsd-rs/lsd

# Zoxide (Directory Navigator)
zinit ice from"gh-r" as"command"
zinit load ajeetdsouza/zoxide

# FZF (fuzzy finder)
zinit ice from"gh-r" as"command"
zinit load junegunn/fzf

# Atuin (Enhanced Shell History)
zinit ice as"command" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin init zsh --disable-up-arrow > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" src"init.zsh"
zinit light atuinsh/atuin

# ================================================================================================
# Zsh Plugins
# ================================================================================================

# Extra zsh completions - load with turbo mode
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions

# Syntax highlighting
zinit light zsh-users/zsh-syntax-highlighting

# Auto-suggestions
zinit ice wait lucid atload"!_zsh_autosuggest_start"
zinit load zsh-users/zsh-autosuggestions

# History substring search
zinit light zsh-users/zsh-history-substring-search

# You should use plugin
zinit light MichaelAquilina/zsh-you-should-use

# ================================================================================================
# Initialize completions AFTER all plugins are loaded
# ================================================================================================

# Only regenerate compdump once a day
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
