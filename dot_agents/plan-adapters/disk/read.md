# Disk adapter — read

Read the exact contents of one plan file.

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
- `<file>` — the file name inside the task's plan directory (e.g.
  `PRD.md`, `001-disk-adapter.md`).

## Recipe
Use the Read tool on exactly:

```
<location>/<file>
```

The tool returns the file's full contents, unmodified. A missing file makes
the Read fail; never silently substitute empty content for a missing file.
