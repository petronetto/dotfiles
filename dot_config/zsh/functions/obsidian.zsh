#!/usr/bin/env zsh

export OBSIDIAN_VAULT="$HOME/Obsidian/Default"

# Create a note at the given vault-relative path, opening it in $EDITOR.
# Usage: mknote path/to/note.md
function mknote() {
  if [[ -z "$1" ]]; then
    echo "Usage: mknote <vault-relative/path/to/note.md>"
    return 1
  fi

  local note_path="${OBSIDIAN_VAULT}/${1}"
  local note_dir="${note_path:h}"

  mkdir -p "$note_dir" || return 1

  if [[ ! -f "$note_path" ]]; then
    printf -- "---\ncreated: %s\n---\n\n" "$(date '+%Y-%m-%d %H:%M')" > "$note_path"
  fi
}

# Create a temporary note under $OBSIDIAN_VAULT/tmp/.
# Usage: tmpnote [name.md]  (defaults to a timestamp-based name)
function tmpnote() {
  local name="${1:-$(date '+%Y%m%d-%H%M%S').md}"
  [[ "$name" != *.md ]] && name="${name}.md"
  mknote "tmp/${name}"
}

# Create a handoff note under $OBSIDIAN_VAULT/handoff/.
# Usage: handoff [name]  (defaults to a timestamp-based name)
function handoff() {
  local name="${1:-$(date '+%Y%m%d-%H%M%S').md}"
  [[ "$name" != *.md ]] && name="${name}.md"
  mknote "handoff/${name}"
}
