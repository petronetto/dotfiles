#!/usr/bin/env zsh
set -euo pipefail

(( EUID != 0 )) && [[ "$OSTYPE" == linux* ]] || { print -u2 'Ubuntu non-root execution is required'; exit 1; }
readonly selected="${1:?catalog command is required}"
readonly work="${UBUNTU_SMOKE_DIR:?isolated smoke directory is required}"
cd "$work"
print -r -- "Testing credential-free local behavior: $selected"

expect() {
  [[ "$1" == "$2" ]] && return 0
  print -u2 -r -- "Expected [$2], received [$1]"
  return 1
}

case "$selected" in
  zsh)
    startup_code=0
    env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_RUNTIME_DIR zsh -lic '
      set -e
      [[ "$aliases[vim]" == nvim && "$aliases[cat]" == bat && "$aliases[dc]" == "docker compose" ]]
      (( $+functions[clipboard_copy] && $+functions[__zoxide_z] ))
      [[ -f "$STARSHIP_CONFIG" && -f "$ZDOTDIR/.zsh_plugins.zsh" ]]
      [[ -z "${XDG_RUNTIME_DIR:-}" ]]
      command -v node pi td >/dev/null
      print fixture | clipboard_copy
      cd "$UBUNTU_SMOKE_DIR"
      ..
      [[ "$PWD" == "${UBUNTU_SMOKE_DIR:h}" ]]
    ' 2> "$work/startup-stderr" || startup_code=$?
    command cat "$work/startup-stderr" >&2
    (( startup_code == 0 )) && [[ ! -s "$work/startup-stderr" ]]
    ;;
  git)
    git -c init.defaultBranch=main init -q project
    git -C project config user.name 'Dotfiles Fixture'
    git -C project config user.email tester@example.invalid
    git -C project config commit.gpgsign false
    git -C project config core.hooksPath /dev/null
    print fixture > project/file.txt
    git -C project add file.txt
    git -C project commit -qm fixture
    expect "$(git -C project show HEAD:file.txt)" fixture
    ;;
  curl)
    print fixture > input.txt
    expect "$(curl --disable --fail --silent --show-error "file://$work/input.txt")" fixture
    ;;
  jq)
    expect "$(printf '%s' '{"values":[20,22]}' | jq -r '.values | add')" 42
    ;;
  rg)
    printf 'other\nneedle\n' > input.txt
    expect "$(rg --fixed-strings --no-heading --no-line-number --color never needle input.txt)" needle
    ;;
  fd)
    print fixture > sample.txt
    [[ "$(fd --type f '^sample\.txt$' .)" == *sample.txt ]]
    ;;
  bat)
    print fixture > input.txt
    expect "$(bat --paging=never --style=plain --color=never input.txt)" fixture
    ;;
  fzf)
    expect "$(printf 'other\nneedle\n' | fzf --filter=needle)" needle
    ;;
  zoxide)
    export _ZO_DATA_DIR="$work/zoxide"
    mkdir -p "$_ZO_DATA_DIR"
    zoxide add "$work"
    expect "$(zoxide query "$work")" "$work"
    ;;
  lsd)
    print fixture > sample.txt
    expect "$(lsd --color never --icon never -1 .)" sample.txt
    ;;
  delta)
    printf 'diff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +1 @@\n-old\n+new\n' > input.diff
    output="$(delta --paging=never --color-only < input.diff)"
    [[ "$output" == *old* && "$output" == *new* ]]
    ;;
  atuin)
    atuin init zsh >/dev/null
    export ATUIN_CONFIG_DIR="$work/atuin"
    mkdir -p "$ATUIN_CONFIG_DIR"
    printf 'auto_sync = false\nupdate_check = false\ndb_path = "%s/history.db"\nrecord_store_path = "%s/records.db"\n' \
      "$ATUIN_CONFIG_DIR" "$ATUIN_CONFIG_DIR" > "$ATUIN_CONFIG_DIR/config.toml"
    export ATUIN_SESSION="$(atuin uuid)"
    history_id="$(atuin history start 'printf fixture-history')"
    atuin history end --exit 0 --duration 1 "$history_id"
    [[ "$(atuin search --search-mode fulltext --format '{command}' fixture-history)" == *fixture-history* ]]
    ;;
  tmux)
    socket="dotfiles-smoke-$$"
    trap 'tmux -L "$socket" kill-server >/dev/null 2>&1 || true' EXIT
    tmux -L "$socket" -f "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" new-session -d -s fixture /bin/zsh -f
    tmux -L "$socket" send-keys -t fixture "printf pane-fixture > '$work/pane-output'; tmux -L '$socket' wait-for -S done" Enter
    tmux -L "$socket" wait-for done
    expect "$(< "$work/pane-output")" pane-fixture
    ;;
  nvim)
    nvim --headless -n -i NONE input.txt \
      -c 'if !empty(v:errmsg) | cquit | endif' \
      -c 'lua vim.api.nvim_buf_set_lines(0, 0, -1, false, {"editor-fixture"})' \
      -c write -c 'if !empty(v:errmsg) | cquit | endif' -c 'qa!'
    expect "$(< input.txt)" editor-fixture
    ;;
  chezmoi)
    expect "$(chezmoi execute-template '{{ .chezmoi.os }}:{{ .profile }}')" linux:test-container
    ;;
  mise)
    [[ "$(mise current node)" == 24.* ]]
    expect "$(mise exec -- node -p '6 * 7')" 42
    ;;
  node)
    expect "$(node -p '6 * 7')" 42
    ;;
  npm)
    expect "$(npm config get prefix)" "$HOME/.local"
    printf '%s\n' '{"name":"dotfiles-fixture","version":"1.0.0"}' > package.json
    expect "$(npm pkg get name)" '"dotfiles-fixture"'
    ;;
  npx)
    mkdir -p node_modules/.bin
    printf '#!/bin/sh\nprintf "local-cli-fixture\\n"\n' > node_modules/.bin/dotfiles-fixture
    chmod 0755 node_modules/.bin/dotfiles-fixture
    expect "$(npx --offline --yes -- dotfiles-fixture)" local-cli-fixture
    ;;
  starship)
    git -c init.defaultBranch=main init -q "$work"
    git -C "$work" -c user.name=Fixture -c user.email=tester@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --allow-empty -qm fixture
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/lambda.toml"
    [[ -f "$STARSHIP_CONFIG" ]]
    prompt_code=0
    prompt="$(starship prompt --path "$work" --status 0 2> "$work/prompt-stderr")" || prompt_code=$?
    command cat "$work/prompt-stderr" >&2
    (( prompt_code == 0 )) && [[ "$prompt" == *main* && ! -s "$work/prompt-stderr" ]]
    ;;
  ast-grep)
    print 'const answer = 6 * 7;' > fixture.js
    ast-grep run --lang javascript --pattern '$A * $B' --json=compact fixture.js | jq -e 'length == 1' >/dev/null
    ;;
  *) print -u2 -r -- "No baseline smoke implementation for $selected"; exit 1 ;;
esac
print -r -- "PASS: $selected meaningful local behavior"
