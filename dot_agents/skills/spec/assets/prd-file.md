# <Task Title> — PRD

| Field    | Value                 |
| ------- | -------------------- |
| Status   | pending                |
| Date     | YYYY-MM-DD              |
| Project | <project-full-path>    |
| Branch   | <branch>                |
| Task     | <task-name>             |
| Roadmap  | <entry in `.plans/roadmap/ROADMAP.md` this PRD implements (e.g. E02), or none> |

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
instead of restating it. The discovery findings and provenance behind these
decisions live in `CONTEXT.md`; durable cross-cutting decisions with real
alternatives are promoted to `ADR-NNN` files and linked from the Key
decisions table below.

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
`plan` decomposes this PRD into step files and maintains the plan's review
surface (step index, dependencies, flow) in `FLOW.md` next to this file.
Do not duplicate step details here.

## Key decisions
Decisions resolved during the interview that constrain multiple steps
(naming, library/framework choices, data model, boundaries), each with a
one-line rationale and a link to its traceability, so a reviewer or a fresh
sub-agent with no memory of the interview doesn't re-litigate or contradict
them.

| #  | Decision | Rationale | Traceability |
| -- | -------- | --------- | ------------ |
| D1 | <…>     | <one line> | Q3 / ADR-001 / CONTEXT.md › <topic> |

## Risks & open questions
Known risks or deferred questions that could affect later steps, if any.
