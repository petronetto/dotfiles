# Obsidian adapter — read

Read the exact contents of one plan note.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; every CLI call below
  selects the vault with `vault=<obsidian.vault>`.
- `obsidian.folder` — read from `~/.agents/plans.config.md`, the one
  global config that names this adapter. Replace any `<repo-name>` in the
  value with the repo's directory name; drop a trailing `/`; an empty
  folder is invalid. The vault-relative plans folder.
- `location=<dir>` — `<obsidian.folder>/<task-name>`: the task's
  vault-relative subfolder, already including the task name. The task
  name is its git-safe slug (lowercase letters, digits, hyphens), or
  `roadmap` for the branch-independent roadmap task.
- `<file>` — the note's name inside the task subfolder (e.g. `PRD.md`,
  `002-obsidian-adapter.md`). Each plan file is a note with the same name
  it has on disk, `.md` included, per ADR-002.

## Recipe
Run exactly one command:

```bash
obsidian vault=<obsidian.vault> read path="<location>/<file>"
```

The output is the note's full contents, frontmatter included, unmodified —
byte-identical for a note ending in a final newline; a note that lacks
one gets a newline appended to the read output. A missing note prints `Error: File "<location>/<file>" not found.` while
the CLI still exits 0; never treat that line as the note's content, and
never silently substitute empty content for a missing note.
