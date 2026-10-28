#!/usr/bin/env zsh

clipboard_copy() {
  if [[ "$OSTYPE" == darwin* ]] && command -v pbcopy >/dev/null; then
    pbcopy 2>/dev/null || true
    return
  fi
  if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]] && command -v wl-copy >/dev/null; then
    wl-copy 2>/dev/null || true
    return
  fi
  if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null; then
    xclip -selection clipboard 2>/dev/null || true
    return
  fi
  command cat >/dev/null
}
