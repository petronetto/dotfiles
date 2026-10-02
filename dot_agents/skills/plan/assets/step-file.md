# NNN - <Task Title>

| Field   | Value                             |
| ------- | ---------------------------------- |
| Status  | pending                            |
| Date    | YYYY-MM-DD                         |
| Depends | <previous step file(s), or none>   |
| Blocked | <reason, only if Status is blocked>|

Status values: `pending` --> `in-progress` --> `done`, or `blocked` if still unresolved after review cycles.

Write in ASD-STE100 Simplified Technical English. Use common words and
define necessary technical terms. Remove template instructions when done.

## Delivers
One sentence: what this step changes. Link to the `PRD.md` goal and
`decisions.md` for the reason; do not repeat them.

## Out of scope
One line: what this step must NOT touch, including boundaries to preserve.

## Chunks
| # | Change (verb first, one action) | Files | Done when |
| - | ------------------------------- | ----- | --------- |
| 1 | <verb-first instruction>        | <file(s) touched> | <observable outcome> |

Use one action per row and one sentence per cell. "Done when" states a result
that can be checked. Explain how only if needed. Keep reasons in `decisions.md`.

## Verify
Link checks to `SPEC.md` requirement and scenario IDs (or preservation checks
for a pure refactor). Give commands and expected results. Use manual checks
only when automated checks are not possible; state what to check and expect.
Test behavior, not implementation. Use Arrange, Act, Assert (AAA) and replace
external dependencies with test doubles.

## Acceptance
- [ ] Concrete, checkable condition for "done".

## Review log
(Appended during implementation/review cycles.)

## Commit
(Filled in only after approval: commit SHA and final commit message used.)
