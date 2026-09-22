# Disk adapter — read

Read the exact contents of one plan file.

## Inputs
- `location=<dir>` — printed by `resolve.sh`.
- `<file>` — the file name inside the task's plan directory (e.g.
  `PRD.md`, `001-disk-adapter.md`).

## Recipe
Use the Read tool on exactly:

```
<location>/<file>
```

The tool returns the file's full contents, unmodified. A missing file makes
the Read fail; never silently substitute empty content for a missing file.
