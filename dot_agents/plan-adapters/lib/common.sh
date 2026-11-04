# shellcheck shell=bash
# Shared helpers for the plan CLI and its backends.
# Sourced by the dispatcher (plan) and by every backend; never run directly.

# Print a prefixed error on stderr and exit 1.
die() {
  printf 'plan: %s\n' "$*" >&2
  exit 1
}

# Print the git repo root of the current directory (cached per process).
plan_repo_root() {
  if [[ -n "${PLAN_REPO_ROOT:-}" ]]; then
    printf '%s\n' "$PLAN_REPO_ROOT"
    return 0
  fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a git repository; a relative plans root needs one"
  PLAN_REPO_ROOT="$root"
  printf '%s\n' "$root"
}

# plan_config_get <section> <key>
# Print one value from the plans config ($PLAN_CONFIG, or
# ~/.agents/plans.config.md). Format: a 'section:' line, then indented
# '  key: value' lines under it. Dies when the key is absent.
plan_config_get() {
  local section="$1" key="$2"
  local file="${PLAN_CONFIG:-$HOME/.agents/plans.config.md}"
  [[ -f "$file" ]] || die "plans config not found: $file"
  local line cur="" k v
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([A-Za-z0-9_-]+):$ ]]; then
      cur="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+([A-Za-z0-9_-]+):[[:space:]]*(.+)$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      v="${v%"${v##*[![:space:]]}"}"
      if [[ "$cur" == "$section" && "$k" == "$key" ]]; then
        printf '%s\n' "$v"
        return 0
      fi
    fi
  done < "$file"
  die "plans config ($file) has no '$section.$key'"
}

# plan_subst_repo_name <value>
# Print value with every <repo-name> replaced by the project's directory
# name: the git repo's top-level directory when the working directory is
# inside one, otherwise the working directory's own name.
plan_subst_repo_name() {
  # Runs inside command substitutions, where errexit is not inherited
  # (inherit_errexit is off): every capturing assignment is guarded so a
  # failure still aborts this shell and propagates to the caller.
  local value="$1" repo
  if [[ "$value" == *"<repo-name>"* ]]; then
    repo="$(git rev-parse --show-toplevel 2>/dev/null)" || repo=""
    if [[ -z "$repo" ]]; then
      # Outside a git repository: fall back to the working directory's name.
      repo="$(pwd -P)"
      repo="${repo%/}"
      repo="${repo##*/}"
      [[ -n "$repo" ]] \
        || die "cannot derive <repo-name>: the current directory is the filesystem root"
    fi
    value="${value//<repo-name>/${repo##*/}}"
  fi
  printf '%s\n' "$value"
}

# plan_validate_task <name>
# Task names are git-safe slugs (lowercase letters, digits, hyphens),
# or the fixed name 'roadmap'.
plan_validate_task() {
  local task="$1"
  [[ "$task" =~ ^[a-z0-9][a-z0-9-]*$ ]] \
    || die "invalid task name: '$task' (lowercase letters, digits, hyphens)"
}

# plan_validate_file <relative-path>
# Permit nested artifacts, but never absolute paths or traversal components.
plan_validate_file() {
  local file="$1" component rest="$1"
  [[ "$file" =~ ^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$ ]] \
    || die "invalid plan file name: '$file'"
  while [[ -n "$rest" ]]; do
    component="${rest%%/*}"
    [[ "$component" != "." && "$component" != ".." ]] \
      || die "invalid plan file name: '$file'"
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
}

# plan_file_path <task-directory> <relative-path>
# Reject symlinks at the task root, in parents, and at the file itself.
plan_file_path() {
  local dir="${1%/}" file="$2" component rest="$2"
  plan_validate_file "$file"
  [[ ! -L "$dir" ]] || die "symlink plan directory is not allowed: $dir"
  while [[ -n "$rest" ]]; do
    component="${rest%%/*}"
    dir="$dir/$component"
    [[ ! -L "$dir" ]] || die "symlink plan path is not allowed: $dir"
    [[ "$rest" == */* ]] || break
    rest="${rest#*/}"
  done
  printf '%s\n' "$dir"
}

# plan_files_in <task-directory>
# Return relative artifact names, not filesystem paths or symlink targets.
plan_files_in() {
  local dir="$1" links
  [[ ! -L "$dir" ]] || die "symlink plan directory is not allowed: $dir"
  links="$(find "$dir" -type l -print)" || die "could not inspect plan directory: $dir"
  [[ -z "$links" ]] || die "symlink plan paths are not allowed: $links"
  (cd -- "$dir" && find . -type f -print) | LC_ALL=C sort | cut -c 3-
}

# plan_parse_set_status <location> --entry <id> --status <status>
# Parse and validate the set-status arguments; results land in the
# PLAN_SS_* globals. Dies on any contract violation.
plan_parse_set_status() {
  PLAN_SS_LOCATION="" PLAN_SS_ENTRY="" PLAN_SS_STATUS=""
  [[ -n "${1:-}" ]] \
    || die "usage: plan set-status <location> --entry <id> --status <status>"
# shellcheck disable=SC2034
  PLAN_SS_LOCATION="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --entry)
        [[ -n "${2:-}" ]] || die "--entry needs an entry ID"
        PLAN_SS_ENTRY="$2"
        shift 2
        ;;
      --status)
        [[ -n "${2:-}" ]] || die "--status needs a value"
        PLAN_SS_STATUS="$2"
        shift 2
        ;;
      *) die "unknown set-status argument: $1" ;;
    esac
  done
  [[ -n "$PLAN_SS_ENTRY" ]] || die "--entry is required"
  [[ "$PLAN_SS_ENTRY" =~ ^[A-Za-z0-9_-]+$ ]] \
    || die "invalid entry ID: '$PLAN_SS_ENTRY'"
  [[ -n "$PLAN_SS_STATUS" ]] || die "--status is required"
  case "$PLAN_SS_STATUS" in
    planned | in-progress | done | deferred) ;;
    *) die "invalid status '$PLAN_SS_STATUS' for a roadmap target" ;;
  esac
}

# The roadmap Status cell is the sixth column. Preserve the other cells.
# shellcheck disable=SC2016
PLAN_STATUS_AWK='
BEGIN {
  AWK_STATUS = ENVIRON["AWK_STATUS"]
  AWK_ENTRY = ENVIRON["AWK_ENTRY"]
}

function fail(msg) {
  printf "plan: %s\n", msg > "/dev/stderr"
  exit 1
}

# split_cell(s): split "lead<value>suffix" into CELL_LEAD / CELL_VALUE /
# CELL_SUFFIX. suffix is the trailing whitespace plus the closing pipe, when
# present. Fails on rows with more than one trailing cell.
function split_cell(s, r2) {
  r2 = s
  sub(/^[ \t]*/, "", r2)
  CELL_LEAD = substr(s, 1, length(s) - length(r2))
  if (!match(r2, /[ \t]*(\|[ \t]*)?$/)) fail("malformed table row: " s)
  CELL_SUFFIX = substr(r2, RSTART)
  CELL_VALUE = substr(r2, 1, RSTART - 1)
}

{
  lines[++n] = $0
  if (!ri && index($0, "| " AWK_ENTRY " ") == 1) ri = n
}

END {
  if (ri == 0) fail("no roadmap row for entry: " AWK_ENTRY)
  np = split(lines[ri], c, "|")
  if (np < 8) fail("roadmap row has fewer than six columns: " lines[ri])
  split_cell(c[7])
  if (CELL_VALUE !~ /^(planned|in-progress|done|deferred)$/) {
    fail("unexpected Status column value: '"'"'" CELL_VALUE "'"'"'")
  }
  c[7] = CELL_LEAD AWK_STATUS CELL_SUFFIX
  out = c[1]
  for (i = 2; i <= np; i++) out = out "|" c[i]
  lines[ri] = out
  for (i = 1; i <= n; i++) print lines[i]
}
'

# plan_apply_status <status> <entry-id>
# Filter: stdin is the file's current content, stdout its new content.
# Dies (nonzero exit, message on stderr) on a malformed target.
plan_apply_status() {
  AWK_STATUS="$1" AWK_ENTRY="$2" \
    awk "$PLAN_STATUS_AWK"
}

# plan_append_file <path>
# Append stdin to the file, creating it when absent or empty. Existing
# content keeps its final newline (repaired when missing) and exactly one
# blank line separates it from the appended block.
plan_append_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    cat > "$path"
    return 0
  fi
  if [[ -n "$(tail -c 1 "$path")" ]]; then
    printf '\n' >> "$path"
  fi
  printf '\n' >> "$path"
  cat >> "$path"
}

# plan_set_status_in <dir>
# Apply the parsed set-status (plan_parse_set_status must have run) to the
# plan file inside <dir>. The rewrite goes through a temp file created next
# to the target: a malformed target is never touched, and the final
# replace is an atomic rename on the same filesystem.
plan_set_status_in() {
  local dir="$1" path tmp
  path="$(plan_file_path "$dir" ROADMAP.md)" || exit 1
  [[ -f "$path" ]] || die "plan file not found: $path"
  tmp="$(mktemp "${path%/*}/.plan-set-status.XXXXXX")"
  if ! plan_apply_status "$PLAN_SS_STATUS" "$PLAN_SS_ENTRY" \
    < "$path" > "$tmp"; then
    rm -f "$tmp"
    exit 1
  fi
  if ! mv -f -- "$tmp" "$path"; then
    rm -f "$tmp"
    die "could not update plan file: $path"
  fi
}
