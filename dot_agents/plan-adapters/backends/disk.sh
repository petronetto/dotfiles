# shellcheck shell=bash
# Disk backend: plan files in a directory tree on the local filesystem.
# Sourced by the plan dispatcher; implements the six ops as disk_* functions.
# All ops but init take a <location>, the resolved task directory printed
# by init and listed by list.

# Print the resolved plans root: config disk.root, with <repo-name>
# substituted and relative values prefixed with the git repo root.
disk_root() {
  local root
  root="$(plan_config_get disk root)"
  root="${root%/}"
  [[ -n "$root" ]] || die "disk.root is empty in the plans config"
  # shellcheck disable=SC2088
  case "$root" in
    "~/"*) root="$HOME/${root#"~/"}" ;;
  esac
  if [[ "$root" == *"<repo-name>"* || "$root" != /* ]]; then
    root="$(plan_subst_repo_name "$root")"
    if [[ "$root" != /* ]]; then
      root="$(plan_repo_root)/${root#./}"
    fi
  fi
  printf '%s\n' "$root"
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
  plan_validate_file "$2"
  local path="$1/$2"
  [[ -f "$path" ]] || die "plan file not found: $path"
  cat -- "$path"
}

disk_write() {
  [[ $# -eq 2 ]] || die "usage: plan write <location> <file>"
  plan_validate_file "$2"
  local location="$1"
  [[ -d "$location" ]] || die "plan directory not found: $location (run init first)"
  cat > "$location/$2"
}

disk_append() {
  [[ $# -eq 2 ]] || die "usage: plan append <location> <file>"
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
  [[ -d "$1" ]] || die "plan directory not found: $1 (run init first)"
  printf '%s\n' "$1"
}

disk_set_status() {
  plan_parse_set_status "$@"
  plan_set_status_in "$PLAN_SS_LOCATION"
}