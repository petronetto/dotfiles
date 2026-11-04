# Plan adapters

The `plan` CLI is the storage interface for the unified skill set:
`blueprint`, `explore`, `propose`, `build`, `build-auto`, `review`, and `test`.
Skills use it whenever they need saved artifacts. Blueprint owns the project
charter and roadmap; changes use proposal/specs/design/tasks. Review reads
project boundaries, and test discovers commands from the stack.
See [Change storage adapter](change-workflow.md) for storage mapping and the
bundled schema.

## Usage

```
plan <op> [args]
```

| Op          | Call                                             | Contract |
| ----------- | ------------------------------------------------ | -------- |
| `init`      | `plan init <task-name>`                          | Create the task's directory, idempotent; print its `<location>`. Task names are git-safe slugs (lowercase letters, digits, hyphens), or the fixed name `roadmap`. |
| `read`      | `plan read <location> <file>`                    | Print one plan file's exact content on stdout; fail when absent. |
| `files`     | `plan files <location>`                         | Print sorted task-relative file paths recursively; fail on symlinks. Read-only, implemented by the dispatcher using the backend's `path` operation. |
| `write`     | `plan write <location> <file>`                   | Replace one plan file with the content on stdin (heredoc); content is the entire file. |
| `append`    | `plan append <location> <file>`                  | Append stdin to one plan file, creating it when absent; one blank line separates existing content from the appended block. |
| `list`      | `plan list`                                      | Print every task's `<location>`, one per line, sorted; no tasks prints nothing. |
| `set-status`| `plan set-status <location> --entry <id> --status <status>` | Change only the roadmap entry's Status cell. Statuses: `planned`, `in-progress`, `done`, `deferred`. |
| `path`      | `plan path <location>`                           | Print the `<location>`'s on-disk directory (for opening files, not for plan-file operations). |

Common rules:

- Data goes to stdout, errors to stderr with a nonzero exit.
- Never inline a plan path: every `<location>` comes from `init` or `list`
  output, and every operation goes through this CLI. That invariant is what
  keeps the whole skill suite in agreement on the location. Backends enforce
  it: a `<location>` outside the backend's plans root is rejected.
- `<file>` can be a flat filename or a nested relative artifact path, such
  as `specs/identity/user-auth/spec.md`. `write` and `append` create missing
  parent directories. Absolute paths, empty components, `.` and `..`
  components, and symlinks inside a task are rejected. Existing flat-file
  operations and roadmap status updates keep their previous behavior.

## Change tracking

`.change.yaml` selects a schema and optional `skip_specs: true`. A pure
refactor names preserved behavior and checks in its proposal and produces
no spec delta. For a named epic, `propose` records `roadmap_entry: E01` using
the actual ID, sets that entry in-progress, and fills its Change column.
Build workflows set it done only after all groups and the final audit pass.

Task groups in `tasks.md` use descriptive headings and a plain `Depends:`
line naming prerequisite groups or `none`, never a checkbox. Each group
has one responsibility, can be reviewed and reverted alone, and leaves code
working. Tasks name files, requirements/scenarios or preservation checks,
and observable completion checks. Dependencies are acyclic; independent
groups with disjoint files may build in parallel using Worktrunk (`wt`).
Checkboxes track work, not approval. Group approval and final-audit gates
belong to `build` and `build-auto`; no persistent blocked state or review log
is added.

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
  git repo root; absolute roots are used as-is. `<repo-name>` in the value is
  replaced with the project's directory name: the git repo's top-level
  directory when inside one, otherwise the current working directory's name.
  A relative root still requires a git repo, because it has no other anchor.
- `obsidian`: plan notes inside an Obsidian vault, one note per plan file.
  Requires the `obsidian` CLI and a vault it knows. `obsidian.folder` is
  vault-relative and supports `<repo-name>` with the same substitution as
  `disk.root`, so plans from different projects can live side by side. Content ops write to the vault's on-disk path (the CLI's
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
   `<repo-name>` substitution, task and relative file validation, safe
   artifact path resolution, recursive file inventory, set-status
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
├── backends/
│   ├── disk.sh     # local filesystem backend (default)
│   └── obsidian.sh # Obsidian vault backend
├── change-workflow.md
└── schemas/
    └── spec-driven/
        ├── schema.yaml
        └── templates/
            ├── proposal.md
            ├── spec.md
            ├── design.md
            └── tasks.md
```

## Verification

Run `bash -n` and ShellCheck on changed adapter scripts. Exercise roadmap
entry updates with temporary storage, never a real vault. Use
`chezmoi apply --dry-run` and `chezmoi diff` to inspect deployment changes
without applying them.
