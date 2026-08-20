#!/usr/bin/env zsh

# Transient prompt: after each command, collapse the full starship prompt to the
# character only, so just the prompt you are typing stays full. Left-only variant.
# Ref: https://github.com/starship/starship/discussions/5950
#
# Needs a `transient` profile in the active starship config (see lambda.toml / nerd.toml).
# Must be sourced after `eval "$(starship init zsh)"` (init.zsh runs first, config/ after).

autoload -Uz add-zsh-hook add-zle-hook-widget

# Same string as PROMPT, but the starship call is pointed at the transient profile.
TRANSIENT_PROMPT="${PROMPT// prompt / prompt --profile transient }"

# Re-arm the Ctrl-C handler on each command boundary so interrupted commands also
# land on the (collapsed) transient line.
transient-prompt-precmd() {
  TRAPINT() { transient-prompt; return $((128 + $1)) }
  SAVED_PROMPT="$TRANSIENT_PROMPT"
}

transient-prompt() {
  PROMPT="$SAVED_PROMPT" RPROMPT="" zle .reset-prompt
}

add-zsh-hook precmd transient-prompt-precmd
add-zle-hook-widget zle-line-finish transient-prompt
