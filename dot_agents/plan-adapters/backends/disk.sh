# shellcheck shell=bash
# Disk backend: plan files in a directory tree on the local filesystem.
# Sourced by the plan dispatcher; implements the seven ops as disk_* functions.
# All ops but init take a <location>, the resolved task directory printed
# by init and listed by list.

# Print the resolved plans root: config disk.root, with <repo-name>
# substituted and relative values prefixed with the git repo root.
disk_root() {
  local root
  # Runs inside command substitutions, where errexit is not inherited: every
  # capturing assignment is guarded so a failure still aborts this shell.
  root="$(plan_config_get disk root)" || exit 1
  root="${root%/}"
  [[ -n "$root" ]] || die "disk.root is empty in the plans config"
  # shellcheck disable=SC2088
  case "$root" in
    "~/"*) root="$HOME/${root#"~/"}" ;;
  esac
  if [[ "$root" == *"<repo-name>"* || "$root" != /* ]]; then
    root="$(plan_subst_repo_name "$root")" || exit 1
    if [[ "$root" != /* ]]; then
      root="$(plan_repo_root)/${root#./}" || exit 1
    fi
  fi
  printf '%s\n' "$root"
}

# disk_validate_location <location>
# Every location is the plans root plus one directory name, exactly as
# init prints and list lists: no operation path can escape the plans root.
disk_validate_location() {
  local location="${1%/}" root prefix task
  root="$(disk_root)"
  prefix="${root}/"
  task="${location#"$prefix"}"
  [[ "$task" != "$location" ]] || die "location is outside the plans root: $location"
  [[ -n "$task" && "$task" != */* && "$task" != "." && "$task" != ".." ]] \
    || die "invalid location: $location (expected a task directory from init or list)"
}

disk_init() {
  [[ -n "${1:-}" ]] || die "usage: plan init <task-name>"
  plan_validate_task "$1"
  local location
  location="$(disk_root)/$1"
  mkdir -p -- "$location"
  printf '%s\n' "$location"
}

disk_read() {
  [[ $# -eq 2 ]] || die "usage: plan read <location> <file>"
  disk_validate_location "$1"
  plan_validate_file "$2"
  local path="$1/$2"
  [[ -f "$path" ]] || die "plan file not found: $path"
  cat -- "$path"
}

disk_write() {
  [[ $# -eq 2 ]] || die "usage: plan write <location> <file>"
  disk_validate_location "$1"
  plan_validate_file "$2"
  local location="$1"
  [[ -d "$location" ]] || die "plan directory not found: $location (run init first)"
  cat > "$location/$2"
}

disk_append() {
  [[ $# -eq 2 ]] || die "usage: plan append <location> <file>"
  disk_validate_location "$1"
  plan_validate_file "$2"
  local location="$1"
  [[ -d "$location" ]] || die "plan directory not found: $location (run init first)"
  plan_append_file "$location/$2"
}

disk_list() {
  local root
  root="$(disk_root)"
  [[ -d "$root" ]] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort
}

disk_path() {
  [[ -n "${1:-}" ]] || die "usage: plan path <location>"
  disk_validate_location "$1"
  [[ -d "$1" ]] || die "plan directory not found: $1 (run init first)"
  printf '%s\n' "$1"
}

disk_set_status() {
  plan_parse_set_status "$@"
  disk_validate_location "$PLAN_SS_LOCATION"
  plan_set_status_in "$PLAN_SS_LOCATION"
}
