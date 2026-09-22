#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: resolve.sh <task-name>
       resolve.sh --roadmap

Resolve the active plan adapter and its parameters, then print the
resolved plan location for a task.

Config comes from the first existing plans.config.md:
  1. <repo-root>/plans.config.md
  2. ~/.agents/plans.config.md
  3. built-in default: adapter disk, disk root .plans

A plans.config.md is a Markdown file whose only content is a YAML
frontmatter block, restricted to a flat two-level map with string values
(no lists, anchors, or multiline values). Top-level `adapter` selects the
adapter; its parameters live in a nested section named after the adapter.
Any `<repo-name>` placeholder in a value is replaced with the current
repo's directory name.

Prints key=value lines: adapter, the active adapter's parameters, and
location, the directory holding the task's plan files. --roadmap resolves
the branch-independent roadmap location instead of a task's.

Examples:
  resolve.sh add-retry-logic
  resolve.sh --roadmap
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

strip_quotes() {
  local s="$1"
  case "$s" in
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
  esac
  printf '%s' "$s"
}

# Scalar values only: an unquoted value may carry a trailing ` #` comment,
# but a leading `[` or `{` (YAML list or flow map) is outside the subset and
# dies. Quoted values are taken verbatim. The result lands in $REPLY
# instead of stdout so a die propagates out of parse_config rather than
# being swallowed by the command substitution that would capture it.
scalar_value() {
  local file="$1" lineno="$2" raw="$3"
  raw=$(trim "$raw")
  case "$raw" in
    \"*\"|\'*\')
      ;;
    \#*)
      raw=""
      ;;
    *' #'*)
      raw=$(trim "${raw%%' #'*}")
      ;;
  esac
  case "$raw" in
    \[*|\{*) die "$file:$lineno: unsupported frontmatter value: $raw" ;;
  esac
  REPLY=$(strip_quotes "$raw")
}

# Print `section_key=value` pairs for a single-line { key: value, ... } map.
flow_pairs() {
  local file="$1" lineno="$2" key="$3" rest pair
  rest=$(trim "$4")
  while [ -n "$rest" ]; do
    pair="${rest%%,*}"
    if [ "$pair" = "$rest" ]; then
      rest=""
    else
      rest=$(trim "${rest#*,}")
    fi
    pair=$(trim "$pair")
    [[ $pair =~ ^([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]] \
      || die "$file:$lineno: unsupported frontmatter value: $4"
    scalar_value "$file" "$lineno" "${BASH_REMATCH[2]}"
    printf '%s_%s=%s\n' "$key" "${BASH_REMATCH[1]}" "$REPLY"
  done
}

# Parse a plans.config.md's frontmatter into key=value lines: top-level
# `key: value` becomes key=value; a nested `key:` section with indented
# members (or a single-line { ... } map) becomes key_member=value.
parse_config() {
  local file="$1" line="" tline="" section="" lineno=0 opened=false
  local top_re='^([A-Za-z0-9_-]+):[[:space:]]*(.*)$'
  local indented_re='^[[:space:]]+([A-Za-z0-9_-]+):[[:space:]]*(.*)$'
  local flow_re='^([A-Za-z0-9_-]+):[[:space:]]*\{(.*)\}[[:space:]]*$'
  local pair_re='^([A-Za-z0-9_-]+):[[:space:]]*(.*)$'
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if ! $opened; then
      [ "$line" = "---" ] || die "$file: expected YAML frontmatter starting with ---"
      opened=true
      continue
    fi
    if [ "$line" = "---" ]; then
      return 0
    fi
    tline=$(trim "$line")
    case "$tline" in
      ""|"#"*) continue ;;
    esac
    if [[ $line =~ ^[[:space:]] ]]; then
      [ -n "$section" ] || die "$file:$lineno: indented line outside a section: $tline"
      [[ $line =~ $indented_re ]] || die "$file:$lineno: unsupported frontmatter line: $tline"
      scalar_value "$file" "$lineno" "${BASH_REMATCH[2]}"
      printf '%s_%s=%s\n' "$section" "${BASH_REMATCH[1]}" "$REPLY"
      continue
    fi
    section=""
    if [[ $line =~ $flow_re ]]; then
      flow_pairs "$file" "$lineno" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
      continue
    fi
    [[ $line =~ $top_re ]] || die "$file:$lineno: unsupported frontmatter line: $tline"
    scalar_value "$file" "$lineno" "${BASH_REMATCH[2]}"
    if [ -n "$REPLY" ]; then
      printf '%s=%s\n' "${BASH_REMATCH[1]}" "$REPLY"
    else
      section="${BASH_REMATCH[1]}"
    fi
  done < "$file"
  die "$file: unterminated frontmatter (missing closing ---)"
}

task=""
case "${1:-}" in
  -h|--help|"")
    usage
    exit 0
    ;;
  --roadmap)
    [ "$#" -gt 1 ] && die "unexpected argument: $2"
    task=roadmap
    ;;
  *)
    [ "$#" -gt 1 ] && die "unexpected argument: $2"
    task="$1"
    ;;
esac

[[ $task =~ ^[a-z0-9][a-z0-9-]*$ ]] \
  || die "task-name '$task' must be a git-safe slug (lowercase letters, digits, hyphens)"

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
repo_name=$(basename "$repo_root")

adapter=disk
disk_root=.plans

config_file=""
if [ -f "$repo_root/plans.config.md" ]; then
  config_file="$repo_root/plans.config.md"
elif [ -f "${HOME}/.agents/plans.config.md" ]; then
  config_file="${HOME}/.agents/plans.config.md"
fi

if [ -n "$config_file" ]; then
  pairs=$(parse_config "$config_file")
  while IFS= read -r pair; do
    case "${pair%%=*}" in
      adapter) adapter="${pair#*=}" ;;
      disk_root) disk_root="${pair#*=}" ;;
    esac
  done <<< "$pairs"
fi

disk_root=${disk_root//<repo-name>/$repo_name}

case "$adapter" in
  disk)
    root=${disk_root%/}
    case "$root" in
      /*) location="$root/$task" ;;
      "") die "adapter disk requires a non-empty root" ;;
      *) location="$repo_root/$root/$task" ;;
    esac
    printf 'adapter=%s\n' "$adapter"
    printf 'disk_root=%s\n' "$disk_root"
    printf 'location=%s\n' "$location"
    ;;
  *)
    die "adapter '$adapter' is not supported"
    ;;
esac
