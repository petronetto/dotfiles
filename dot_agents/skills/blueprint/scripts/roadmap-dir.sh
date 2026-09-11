#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/roadmap-dir.sh [--create]

Compute the blueprint directory path for the current repo:
  <project-full-path>/.plans/roadmap/

Unlike scripts/plan-dir.sh, this path is branch-independent on purpose:
the charter and roadmap span branches and outlive any single task.

With --create, also creates the directory if it doesn't exist.

Examples:
  bash scripts/roadmap-dir.sh
  bash scripts/roadmap-dir.sh --create
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

create=false
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --create)
    create=true
    ;;
  "")
    usage
    exit 0
    ;;
  *)
    die "unknown argument: $1 (expected --create)"
    ;;
esac

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"

roadmap_dir="$repo_root/.plans/roadmap"

if $create; then
  mkdir -p "$roadmap_dir"
fi

echo "$roadmap_dir"