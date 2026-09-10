# NNN — <Task Title>

| Field   | Value                             |
| ------- | ---------------------------------- |
| Status  | pending                            |
| Date    | YYYY-MM-DD                         |
| Depends | <previous step file(s), or none>   |
| Blocked | <reason, only if Status is blocked>|

Status values: `pending` → `in-progress` → `done`, or `blocked` if still unresolved after review cycles.

## Delivers
One sentence: what this step changes, and why it sits at this position in the
flow. Link to `PRD.md` and `decisions.md` for the rationale; never restate
them.

## Out of scope
One line: what this step must NOT touch, including boundaries to preserve.

## Chunks
| # | Change (verb first, one action) | Files | Done when |
| - | ------------------------------- | ----- | --------- |
| 1 | <verb-first instruction>        | <file(s) touched> | <observable outcome> |

One action per row, one sentence per cell. "Done when" states what must be
observably true; put mechanics here only where they are non-obvious. Rationale
lives in `decisions.md`, not in this file.

## Verify
Commands to run and their expected results. Manual checks only when no machine
can check them: write exactly what to look at and what to expect. Test
behavior, not implementation. Use AAA and mock external dependencies.

## Acceptance
- [ ] Concrete, checkable condition for "done".

## Review log
(Appended during implementation/review cycles.)

## Commit
(Filled in only after approval: commit SHA and final commit message used.)
