# Disk adapter — write

Create or overwrite one plan file with the given content.

## Inputs
- `location=<dir>` — printed by `resolve.sh`.
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
