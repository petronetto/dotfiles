#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/plan-dir.sh <task-name> [--create]

Compute the plan directory path for the current repo and branch:
  <project-full-path>/.plans/<branch>/<task-name>/

Prints the absolute path to stdout. With --create, also creates it
(and any missing parent directories) if it doesn't already exist.

Examples:
  scripts/plan-dir.sh add-retry-logic
  scripts/plan-dir.sh add-retry-logic --create
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

case "${1:-}" in
  -h|--help|"")
    usage
    exit 0
    ;;
esac

task_name="$1"
create=false
[ "${2:-}" = "--create" ] && create=true

echo "$task_name" | grep -qE '^[a-z0-9][a-z0-9-]*$' \
  || die "task-name '$task_name' must be a git-safe slug (lowercase letters, digits, hyphens)"

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || die "not on a branch (detached HEAD) — check out a branch first"

plan_dir="$repo_root/.plans/$branch/$task_name"

if $create; then
  mkdir -p "$plan_dir"
fi

echo "$plan_dir"
