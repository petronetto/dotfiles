# Disk adapter — init

Create the plan directory for a task. Idempotent by construction: an
existing directory is left untouched.

## Inputs
- `location=<dir>` — printed by `resolve.sh`; the resolved directory
  holding this task's plan files, already including the task name.

## Recipe
Run exactly one command:

```bash
mkdir -p "<location>"
```

`mkdir -p` succeeds whether or not `<location>` already exists, so running
this recipe twice on the same task never errors and never duplicates
anything.
