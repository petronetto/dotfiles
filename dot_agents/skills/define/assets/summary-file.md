# <Task Title> — Plan Summary

| Field    | Value                 |
| ------- | -------------------- |
| Status   | pending                |
| Date     | YYYY-MM-DD              |
| Project | <project-full-path>    |
| Branch   | <branch>                |
| Task     | <task-name>             |

## Problem
What's broken, missing, or requested, and why it matters. 2-4 sentences.

## Goals
What this plan must achieve for it to count as done. Concrete and testable.

## Non-goals
Explicitly excluded work that looks related but is out of scope for this plan.

## Boundaries
Three tiers, from the "scope discipline" principle:
- **Always do:** ... (e.g. run tests before committing, follow naming conventions, validate inputs)
- **Ask first:** ... (e.g. schema changes, adding a dependency, changing CI)
- **Never do:** ... (e.g. commit secrets, edit vendor dirs, remove failing tests without approval)

## Approach
The shape of the solution in prose, before it's broken into steps: the
strategy, and the key architectural/design decisions made during the
interview, with why alternatives were rejected. Step files link back here
instead of restating it.

## Commands
The project's own commands, with flags, so `build`, `test`, and `build-auto`
run the right ones instead of guessing:
```
Build: <build command>
Test:  <focused-test command>
Suite: <full-suite command>
Lint:  <lint command>
Dev:   <dev command, if any>
```

## Steps
Index of step files, filled by `plan` as it writes `NNN-<step-name>.md`.
Kept in sync as steps are added, split, or reordered.
1. `000-<step-name>.md` — ...
2. `001-<step-name>.md` — ...

## Key decisions
Decisions resolved during the interview that constrain multiple steps
(naming, library/framework choices, data model, boundaries), each with a
one-line rationale, so a reviewer or a fresh sub-agent with no memory of
the interview doesn't re-litigate or contradict them.

## Risks & open questions
Known risks or deferred questions that could affect later steps, if any.
