# Obsidian adapter — set-status

Change a Status value: a step note's header-table `Status` row, or a
roadmap entry's `Status` column. Nothing else in the target note changes,
except the step header's `Blocked` row, which moves in lockstep with a
step entering or leaving `blocked`.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; every CLI call below
  selects the vault with `vault=<obsidian.vault>`.
- `obsidian.folder` — read from `~/.agents/plans.config.md`, the one
  global config that names this adapter. Replace any `<repo-name>` in the
  value with the repo's directory name; drop a trailing `/`; an empty
  folder is invalid. The vault-relative plans folder.
- `location=<dir>` — `<obsidian.folder>/<task-name>` as derived above; a
  task location for a step status, the `roadmap` task's location for a
  roadmap status.
- `<step-file>` — the step note's name inside the task subfolder
  (`NNN-*.md`). Given for a step status.
- `<entry-id>` — the roadmap entry's ID (e.g. `E01`). Given for a roadmap
  status.
- `<new-status>` — a step takes `pending`, `in-progress`, `done`, or
  `blocked`; a roadmap entry takes `planned`, `in-progress`, `done`, or
  `deferred`.
- `<blocked-reason>` — a one-line reason; required only when a step's new
  status is `blocked`.

Exactly one of `<step-file>` and `<entry-id>` is given.

The status lives in the note's body — the `| Status |` row of the header
table — exactly as on disk: plan notes are file-for-file copies of the
disk plan files (ADR-002), and the skills read that row, never a
frontmatter field. The recipe below edits the row the same way the disk
adapter does, then rewrites the note whole through write.md.

## Recipe — step note
1. Follow read.md's recipe with `<location>/<step-file>` to read the
   note's current content. Locate the Status row: the header-table line
   beginning `| Status`, and the Blocked row, when present: the
   header-table line beginning `| Blocked`.
2. In that content, replace only the Status row's old status value with
   `<new-status>`; every other character in the line — the `Status` cell,
   the surrounding pipes, the spacing — is byte-identical to what was
   read.
3. Bring the Blocked row in lockstep, in the same content:
   - `<new-status>` is `blocked`: if the Blocked row exists, replace only
     its value with `<blocked-reason>`. If it does not exist, insert a new
     line `| Blocked | <blocked-reason> |` immediately after the `Depends`
     row.
   - the old status was `blocked` and the new one is not: remove the
     Blocked row line entirely.
   - otherwise: no Blocked-row edit.
4. Follow write.md's recipe with `<location>/<step-file>` and the edited
   content: write.md resolves the vault's on-disk path and the Write tool
   overwrites the note in place, whole.

## Recipe — roadmap entry
1. Follow read.md's recipe with `<location>/ROADMAP.md` to read the
   roadmap note's current content. Locate the entry's row: the table line
   whose first cell is `<entry-id>` (e.g. a line beginning `| E01 `).
2. In that content, replace only that row's Status column's value (the
   sixth cell, between the `Depends on` and `PRD` cells) with
   `<new-status>`; every other character in the line is byte-identical to
   what was read.
3. Follow write.md's recipe with `<location>/ROADMAP.md` and the edited
   content.

If anything in the note other than the status cell — and, for a step,
its Blocked row — differs after the rewrite, an edit was wrong. A missing
note surfaces as read.md's `Error: File ... not found.` line; the CLI
still exits 0, so judge by output text.
