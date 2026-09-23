# Plan adapters

The `plan` CLI and its backends: the single interface every plan-aware
skill (`spec`, `plan`, `build`, `build-auto`, `blueprint`, `visual-review`)
uses to read and change plan files, so they always agree on where plans
live and how they are manipulated.

## Usage

```
plan <op> [args]
```

| Op          | Call                                             | Contract |
| ----------- | ------------------------------------------------ | -------- |
| `init`      | `plan init <task-name>`                          | Create the task's directory, idempotent; print its `<location>`. Task names are git-safe slugs (lowercase letters, digits, hyphens), or the fixed name `roadmap`. |
| `read`      | `plan read <location> <file>`                    | Print one plan file's exact content on stdout; fail when absent. |
| `write`     | `plan write <location> <file>`                   | Replace one plan file with the content on stdin (heredoc); content is the entire file. |
| `append`    | `plan append <location> <file>`                  | Append stdin to one plan file, creating it when absent; one blank line separates existing content from the appended block. |
| `list`      | `plan list`                                      | Print every task's `<location>`, one per line, sorted; no tasks prints nothing. |
| `set-status`| `plan set-status <location> (--step <file> \| --entry <id>) --status <status> [--reason <text>]` | Change a step header's `Status` row (or a roadmap entry's `Status` cell) and nothing else; the step's `Blocked` row moves in lockstep with `blocked`. Step statuses: `pending`, `in-progress`, `done`, `blocked`; roadmap statuses: `planned`, `in-progress`, `done`, `deferred`. `--reason` is required exactly when the new status is `blocked`, and must be a single line without `|`. |
| `path`      | `plan path <location>`                           | Print the `<location>`'s on-disk directory (for opening files, not for plan-file operations). |

Common rules:

- Data goes to stdout, errors to stderr with a nonzero exit.
- Never inline a plan path: every `<location>` comes from `init` or `list`
  output, and every operation goes through this CLI. That invariant is what
  keeps the whole skill suite in agreement on the location. Backends enforce
  it: a `<location>` outside the backend's plans root is rejected.

## Backends

`PLAN_BACKEND` selects the backend (`disk` by default). Backend settings
live in `~/.agents/plans.config.md`, one block per backend; only the
active backend's block is read.

```md
---
disk:
  root: .plans
obsidian:
  vault: MyVault
  folder: plans
---
```

- `disk`: plan files under `disk.root`. Relative roots are prefixed with the
  git repo root; absolute roots are used as-is. `<repo-name>` in the value
  is replaced with the repo's directory name.
- `obsidian`: plan notes inside an Obsidian vault, one note per plan file.
  Requires the `obsidian` CLI and a vault it knows. `obsidian.folder` is
  vault-relative. Content ops write to the vault's on-disk path (the CLI's
  `content=` argument rewrites `\n` and `\t` sequences and would corrupt
  plan files); `init` and `list` go through the CLI, whose failures are
  `Error:` output lines with exit 0, so the wrapper judges output text,
  never exit status.

Switching backends does not migrate existing plan files: they stay where
the previous backend put them and become invisible to the suite. Finish or
abandon in-flight plans before switching, or move their files by hand.

## Backend contract

A backend is one sourced file, `backends/<name>.sh`, implementing the seven
ops as `<name>_<op>` functions (hyphenless: `set_status`). The dispatcher:

1. Validates the backend name (lowercase letters, digits, hyphens) before
   sourcing, so `PLAN_BACKEND` can never escape `backends/`.
2. Sources `lib/common.sh`, shared by every backend: `die`, config parsing
   (`plan_config_get <section> <key>`, `$PLAN_CONFIG` overrides the path),
   `<repo-name>` substitution, task and file name validation, set-status
   argument parsing and the status rewrite (`plan_apply_status`,
   `plan_append_file`, `plan_set_status_in`).
3. Checks the backend implements the full interface before dispatch, so a
   half-written backend fails on first contact, with the missing op named.

`PLAN_BACKENDS_DIR` overrides the `backends/` directory the dispatcher
sources from (mainly for testing). The backend name validation still
applies, but the directory itself is trusted like `PATH`.

To add a backend: implement the seven functions in
`backends/<name>.sh`, reuse `lib/common.sh` instead of re-deriving config
or the set-status rewrite, add the backend's settings block to
`plans.config.md`, and keep the CLI's output and error contract.

## Layout

```
plan-adapters/
├── plan            # dispatcher (deployed executable)
├── lib/
│   └── common.sh   # shared helpers, sourced by dispatcher and backends
└── backends/
    ├── disk.sh     # local filesystem backend (default)
    └── obsidian.sh # Obsidian vault backend
```
