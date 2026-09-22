# Disk adapter — write

Create or overwrite one plan file with the given content.

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
- `<file>` — the file name inside the task's plan directory.
- The full intended content of the file.

## Recipe
Use the Write tool on exactly:

```
<location>/<file>
```

with the full intended content. The content passed is the entire file after
the call: an existing file is fully replaced, an absent one created. Never
merge into or splice around existing content here.
