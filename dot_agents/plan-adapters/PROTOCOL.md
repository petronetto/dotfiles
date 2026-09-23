# Plan protocol

The shared rules every plan-aware skill follows (`spec`, `plan`, `build`,
`build-auto`, `blueprint`, `visual-review`), so they always agree on where
plans live and how they are read and changed. Read this file and
`~/.agents/plans.config.md` once per run, before any plan-file operation.

## Config

`~/.agents/plans.config.md` is the one global config. Its `adapter:` key
names the active adapter, one of the directories next to this file (`disk`,
`obsidian`). Adapter-specific settings (for example `disk.root`) live in the
same config.

## Operations

Every plan-file operation follows the matching recipe at
`~/.agents/plan-adapters/<adapter>/<operation>.md`:

| Operation    | Purpose |
| ------------ | ------- |
| `init`       | Resolve the plan directory for a task (`location`); create it when allowed, idempotent |
| `read`       | Read a plan file |
| `write`      | Write a plan file |
| `append`     | Append to a plan file |
| `list`       | Enumerate the task directories |
| `set-status` | Change a `Status` value: a step header's `Status` row, or a roadmap entry's `Status` column |

## Invariant

Never inline a plan path. Every path comes from `init` or `list`, and every
operation goes through its recipe. This is what keeps the whole suite in
agreement on the location.