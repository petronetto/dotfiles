# Disk adapter — list

Enumerate the task directories under the plan root.

## Inputs
- `location=<dir>` — printed by `resolve.sh`. The plan root is the parent
  directory of `<location>`: the directory resolve.sh placed the task in,
  which is `<disk_root>` as resolved.

## Recipe
Run exactly one command:

```bash
find "$(dirname "<location>")" -mindepth 1 -maxdepth 1 -type d | sort
```

Each printed line is one task directory's absolute path. The plan root
itself and files at the root are never listed.
