# NNN — <Task Title>

| Field   | Value                            |
| ------- | -------------------------------- |
| Status  | pending                          |
| Date    | YYYY-MM-DD                       |
| Project | <project-full-path>              |
| Branch  | <branch>                         |
| Depends | <previous step file(s), or none> |

## Goal
One or two sentences describing exactly what this step delivers and why.

## Scope
- In scope: ...
- Out of scope: ... (explicitly list what this step must NOT touch)

## Files & boundaries
Files/modules expected to change, and the boundaries/interfaces involved.

## Implementation chunks
Ordered list of the small chunks this step splits into. Each chunk is a tiny,
self-contained diff the user can review on its own.
1. Chunk A — ...
2. Chunk B — ...

## Verification
How this step is proven correct: tests to add/run, linters, manual checks.
Test behavior, not implementation. Use AAA and mock external dependencies.

## Acceptance criteria
Concrete, checkable conditions that must all hold for the step to be "done".

## Review log
(Appended by spec-build during implementation.)

## Commit
(Filled in only after approval, with the final commit message used.)
