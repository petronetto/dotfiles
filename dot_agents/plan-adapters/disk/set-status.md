# Disk adapter — set-status

Change a Status value: a step file's header-table `Status` row, or a
roadmap entry's `Status` column. Nothing else in the target file changes,
except the step header's `Blocked` row, which moves in lockstep with a
step entering or leaving `blocked`.

## Inputs
- `location=<dir>` — printed by `resolve.sh`; a task location for a step
  status, the `--roadmap` location for a roadmap status.
- `<step-file>` — the step file's name inside the task's plan directory
  (`NNN-*.md`). Given for a step status.
- `<entry-id>` — the roadmap entry's ID (e.g. `E01`). Given for a roadmap
  status.
- `<new-status>` — a step takes `pending`, `in-progress`, `done`, or
  `blocked`; a roadmap entry takes `planned`, `in-progress`, `done`, or
  `deferred`.
- `<blocked-reason>` — a one-line reason; required only when a step's new
  status is `blocked`.

Exactly one of `<step-file>` and `<entry-id>` is given.

## Recipe — step file
1. Use the Read tool on `<location>/<step-file>`. Locate the Status row:
   the header-table line beginning `| Status`, and the Blocked row, when
   present: the header-table line beginning `| Blocked`.
2. Use the Edit tool on `<location>/<step-file>` on the Status row:
   - oldText: the Status row exactly as read.
   - newText: that same line with only the old status value replaced by
     `<new-status>`; every other character in the line — the `Status`
     cell, the surrounding pipes, the spacing — is byte-identical to what
     was read.
3. Bring the Blocked row in lockstep, in the same file:
   - `<new-status>` is `blocked`: if the Blocked row exists, Edit it the
     same way, replacing only its value with `<blocked-reason>`. If it
     does not exist, Edit with oldText the `Depends` row exactly as read
     and newText that same line followed by a new line
     `| Blocked | <blocked-reason> |`.
   - the old status was `blocked` and the new one is not: Edit with
     oldText the Blocked row together with the line immediately above it,
     and newText that line above alone — the Blocked row is removed.
   - otherwise: no Blocked-row edit.

## Recipe — roadmap entry
1. Use the Read tool on `<location>/ROADMAP.md`. Locate the entry's row:
   the table line whose first cell is `<entry-id>` (e.g. a line beginning
   `| E01 `).
2. Use the Edit tool on `<location>/ROADMAP.md`:
   - oldText: the entry's row exactly as read.
   - newText: that same line with only the Status column's value (the
     sixth cell, between the `Depends on` and `PRD` cells) replaced by
     `<new-status>`; every other character in the line is byte-identical
     to what was read.

If anything in the target file other than the status cell — and, for a
step, its Blocked row — differs after the edits, an edit was wrong.
