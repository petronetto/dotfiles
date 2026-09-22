# Disk adapter — init

Create the plan directory for a task. Idempotent by construction: an
existing directory is left untouched.

## Inputs
- `disk.root` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. Replace any `<repo-name>` in the value
  with the repo's directory name; drop a trailing `/`; an empty root is
  invalid. A relative root is prefixed with the repo root
  (`git rev-parse --show-toplevel`); an absolute root is used as-is.
- `location=<dir>` — `<disk.root>/<task-name>`: the resolved directory
  holding this task's plan files, already including the task name. The
  task name is its git-safe slug (lowercase letters, digits, hyphens), or
  `roadmap` for the branch-independent roadmap task.

## Recipe
Run exactly one command:

```bash
mkdir -p "<location>"
```

`mkdir -p` succeeds whether or not `<location>` already exists, so running
this recipe twice on the same task never errors and never duplicates
anything.
