# Disk adapter — list

Enumerate the task directories under the plan root.

## Inputs
- `disk.root` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. Replace any `<repo-name>` in the value
  with the repo's directory name; drop a trailing `/`; an empty root is
  invalid. A relative root is prefixed with the repo root
  (`git rev-parse --show-toplevel`); an absolute root is used as-is.
- `location=<dir>` — `<disk.root>/<task-name>` as derived above. The plan
  root is the parent directory of `<location>`: the directory the task
  was placed in, which is `<disk.root>` as resolved.

## Recipe
Run exactly one command:

```bash
find "$(dirname "<location>")" -mindepth 1 -maxdepth 1 -type d | sort
```

Each printed line is one task directory's absolute path. The plan root
itself and files at the root are never listed.
