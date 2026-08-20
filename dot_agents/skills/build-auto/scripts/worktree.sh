#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/worktree.sh <command> [args]

Manage per-step git worktrees for build-auto's parallel step builds.

Commands:
  create <plan-branch> <step-slug>
      Create an isolated worktree for one step, branched off <plan-branch>.
      Prints the absolute worktree path to stdout on success.
      Idempotent: if a worktree for this step already exists, prints its
      path instead of failing.

  finish <worktree-path> <plan-branch>
      Merge the worktree's branch into <plan-branch> (must be run from a
      checkout of <plan-branch>), then remove the worktree and its branch.
      On merge conflict, the worktree is left in place for manual resolution.

Examples:
  scripts/worktree.sh create feat/foo 003-add-endpoint
  scripts/worktree.sh finish .worktrees/003-add-endpoint feat/foo
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

cmd="${1:-}"
case "$cmd" in
  create)
    plan_branch="${2:?Usage: scripts/worktree.sh create <plan-branch> <step-slug>}"
    step_slug="${3:?Usage: scripts/worktree.sh create <plan-branch> <step-slug>}"
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
    worktree_path="$repo_root/.worktrees/$step_slug"
    step_branch="${plan_branch}-${step_slug}"

    if git worktree list --porcelain | grep -qx "worktree $worktree_path"; then
      echo "$worktree_path"
      exit 0
    fi

    [ -e "$worktree_path" ] && die "$worktree_path exists but is not a registered worktree"

    git rev-parse --verify "$plan_branch" >/dev/null 2>&1 \
      || die "plan branch '$plan_branch' does not exist"

    if git rev-parse --verify "$step_branch" >/dev/null 2>&1; then
      git worktree add "$worktree_path" "$step_branch" >&2
    else
      git worktree add -b "$step_branch" "$worktree_path" "$plan_branch" >&2
    fi
    echo "$worktree_path"
    ;;

  finish)
    worktree_path="${2:?Usage: scripts/worktree.sh finish <worktree-path> <plan-branch>}"
    plan_branch="${3:?Usage: scripts/worktree.sh finish <worktree-path> <plan-branch>}"

    [ -d "$worktree_path" ] || die "worktree path '$worktree_path' does not exist"
    step_branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD) \
      || die "could not resolve branch for worktree '$worktree_path'"

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    [ "$current_branch" = "$plan_branch" ] \
      || die "must be run from a checkout of '$plan_branch' (currently on '$current_branch')"

    git merge --no-ff --no-edit "$step_branch" \
      || die "merge of '$step_branch' into '$plan_branch' failed — resolve conflicts manually, worktree left in place"

    git worktree remove "$worktree_path" >&2
    git branch -d "$step_branch" >&2
    echo "merged $step_branch into $plan_branch"
    ;;

  -h|--help|"")
    usage
    ;;

  *)
    die "unknown command '$cmd' (see --help)"
    ;;
esac
