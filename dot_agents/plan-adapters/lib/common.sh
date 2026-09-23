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
# Print value with every <repo-name> replaced by the repo's directory name.
plan_subst_repo_name() {
  # Runs inside command substitutions, where errexit is not inherited
  # (inherit_errexit is off): every capturing assignment is guarded so a
  # failure still aborts this shell and propagates to the caller.
  local value="$1" repo
  if [[ "$value" == *"<repo-name>"* ]]; then
    repo="$(plan_repo_root)" || exit 1
    value="${value//<repo-name>/$(basename "$repo")}"
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

# plan_validate_file <name>
# A plan file name inside a task directory, never a path.
plan_validate_file() {
  local file="$1"
  if [[ "$file" == "." || "$file" == ".." ]]; then
    die "invalid plan file name: '$file'"
  fi
  [[ "$file" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid plan file name: '$file'"
}

# plan_parse_set_status <location> [--step <file> | --entry <id>] --status <status> [--reason <text>]
# Parse and validate the set-status arguments; results land in the
# PLAN_SS_* globals. Dies on any contract violation.
plan_parse_set_status() {
  PLAN_SS_LOCATION="" PLAN_SS_MODE="" PLAN_SS_STEP="" PLAN_SS_ENTRY=""
  PLAN_SS_STATUS="" PLAN_SS_REASON=""
  [[ -n "${1:-}" ]] \
    || die "usage: plan set-status <location> (--step <file> | --entry <id>) --status <status> [--reason <text>]"
# shellcheck disable=SC2034
  PLAN_SS_LOCATION="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --step)
        [[ -n "${2:-}" ]] || die "--step needs a plan file name"
        PLAN_SS_STEP="$2"
        shift 2
        ;;
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
      --reason)
        [[ -n "${2:-}" ]] || die "--reason needs a value"
        PLAN_SS_REASON="$2"
        shift 2
        ;;
      *) die "unknown set-status argument: $1" ;;
    esac
  done
  if [[ -n "$PLAN_SS_STEP" && -n "$PLAN_SS_ENTRY" ]]; then
    die "give either --step or --entry, not both"
  fi
  if [[ -z "$PLAN_SS_STEP" && -z "$PLAN_SS_ENTRY" ]]; then
    die "one of --step or --entry is required"
  fi
  if [[ -n "$PLAN_SS_STEP" ]]; then
    PLAN_SS_MODE="step"
    plan_validate_file "$PLAN_SS_STEP"
  else
    PLAN_SS_MODE="roadmap"
    [[ "$PLAN_SS_ENTRY" =~ ^[A-Za-z0-9_-]+$ ]] \
      || die "invalid entry ID: '$PLAN_SS_ENTRY'"
  fi
  [[ -n "$PLAN_SS_STATUS" ]] || die "--status is required"
  case "$PLAN_SS_MODE/$PLAN_SS_STATUS" in
    step/pending | step/in-progress | step/done | step/blocked) ;;
    roadmap/planned | roadmap/in-progress | roadmap/done | roadmap/deferred) ;;
    *) die "invalid status '$PLAN_SS_STATUS' for a $PLAN_SS_MODE target" ;;
  esac
  if [[ "$PLAN_SS_STATUS" == "blocked" ]]; then
    [[ -n "$PLAN_SS_REASON" ]] || die "--reason is required when --status is blocked"
    [[ "$PLAN_SS_REASON" != *"|"* ]] || die "--reason must not contain '|'"
    [[ "$PLAN_SS_REASON" != *$'\n'* && "$PLAN_SS_REASON" != *$'\r'* ]] \
      || die "--reason must be a single line"
  else
    [[ -z "$PLAN_SS_REASON" ]] || die "--reason is only valid when --status is blocked"
  fi
}

# The status-row rewrite, shared by every backend: the step header table's
# Status and Blocked rows move in lockstep, and a roadmap row's Status cell
# (the sixth column) is rewritten in place. Only the status value changes;
# every other byte of the input is preserved.
# shellcheck disable=SC2016
PLAN_STATUS_AWK='
BEGIN {
  AWK_MODE = ENVIRON["AWK_MODE"]
  AWK_STATUS = ENVIRON["AWK_STATUS"]
  AWK_REASON = ENVIRON["AWK_REASON"]
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
  if (!si && $0 ~ /^\| Status[ \t]*\|/) si = n
  if (!bi && $0 ~ /^\| Blocked[ \t]*\|/) bi = n
  if (!di && $0 ~ /^\| Depends[ \t]*\|/) di = n
  if (AWK_MODE == "roadmap" && !ri && index($0, "| " AWK_ENTRY " ") == 1) ri = n
}

END {
  if (AWK_MODE == "step") {
    if (si == 0) fail("no Status row found in the step file")
    if (!match(lines[si], /^\| Status[ \t]*\|/)) fail("malformed Status row: " lines[si])
    prefix = substr(lines[si], 1, RLENGTH)
    split_cell(substr(lines[si], RLENGTH + 1))
    if (CELL_VALUE !~ /^(pending|in-progress|done|blocked)$/) {
      fail("unexpected Status value: '"'"'" CELL_VALUE "'"'"'")
    }
    old_status = CELL_VALUE
    lines[si] = prefix CELL_LEAD AWK_STATUS CELL_SUFFIX
    if (AWK_STATUS == "blocked") {
      if (bi) {
        if (!match(lines[bi], /^\| Blocked[ \t]*\|/)) fail("internal: Blocked row vanished")
        bprefix = substr(lines[bi], 1, RLENGTH)
        split_cell(substr(lines[bi], RLENGTH + 1))
        lines[bi] = bprefix CELL_LEAD AWK_REASON CELL_SUFFIX
      } else if (di) {
        for (i = n; i > di; i--) lines[i + 1] = lines[i]
        lines[di + 1] = "| Blocked | " AWK_REASON " |"
        n++
      } else {
        fail("no Depends row found to anchor the Blocked row")
      }
    } else if (old_status == "blocked") {
      if (bi == 0) fail("Status is blocked but the file has no Blocked row")
      for (i = bi; i < n; i++) lines[i] = lines[i + 1]
      n--
    }
  } else {
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
  }
  for (i = 1; i <= n; i++) print lines[i]
}
'

# plan_apply_status <mode> <status> <reason> <entry-id>
# Filter: stdin is the file's current content, stdout its new content.
# Dies (nonzero exit, message on stderr) on a malformed target.
plan_apply_status() {
  AWK_MODE="$1" AWK_STATUS="$2" AWK_REASON="${3:-}" AWK_ENTRY="${4:-}" \
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
  if [[ "$PLAN_SS_MODE" == "step" ]]; then
    path="$dir/$PLAN_SS_STEP"
  else
    path="$dir/ROADMAP.md"
  fi
  [[ -f "$path" ]] || die "plan file not found: $path"
  tmp="$(mktemp "${path%/*}/.plan-set-status.XXXXXX")"
  if ! plan_apply_status "$PLAN_SS_MODE" "$PLAN_SS_STATUS" "$PLAN_SS_REASON" "$PLAN_SS_ENTRY" \
    < "$path" > "$tmp"; then
    rm -f "$tmp"
    exit 1
  fi
  if ! mv -f -- "$tmp" "$path"; then
    rm -f "$tmp"
    die "could not update plan file: $path"
  fi
}
