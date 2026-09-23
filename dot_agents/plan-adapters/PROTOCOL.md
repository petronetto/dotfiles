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

## Switching adapters

Change the `adapter:` key to the adapter directory's name and provide that
adapter's settings block in the same config. The other adapters' blocks may
stay; each block is read only while its adapter is active.

| Adapter    | Required settings |
| ---------- | ---------------- |
| `disk`     | `disk.root`: the plans root; relative roots are prefixed with the repo root, absolute roots are used as-is, `<repo-name>` is replaced with the repo's directory name |
| `obsidian` | `obsidian.vault`: the vault's name. `obsidian.folder`: the vault-relative plans folder, same `<repo-name>` substitution. Requires the `obsidian` CLI and a vault it knows |

Switching does not migrate existing plan files: they stay where the previous
adapter put them and become invisible to the suite. Finish or abandon
in-flight plans before switching, or move their files by hand.

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