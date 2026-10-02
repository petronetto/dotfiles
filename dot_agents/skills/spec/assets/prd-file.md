# <Task Title> - PRD

| Field | Value |
| ----- | ----- |
| Status | pending |
| Date | YYYY-MM-DD |
| Project | <project-full-path> |
| Branch | <branch> |
| Task | <task-name> |
| Roadmap | <roadmap entry ID, such as E02, or none> |

Write this product requirements document (PRD) in ASD-STE100 Simplified
Technical English. Use common words and define necessary technical terms.
Remove template instructions from the finished document.

## Problem
State what is broken, missing, or requested, and why it matters. Use 2-4
short sentences.

## Goals
State the observable results needed to complete this task. Give each goal
an ID and link it to requirements in [SPEC.md](SPEC.md). Keep detailed rules
and test scenarios in SPEC, not here.

- G1: <observable result>. Requirements: <SPEC.md requirement links>.

For a pure refactor, state `No behavior change` and link to the behavior and
checks to preserve in SPEC.

## Non-goals
List related work that this task does not include.

## Boundaries
- **Always do:** <required actions, such as running tests before a commit>
- **Ask first:** <actions that need approval, such as adding a dependency>
- **Never do:** <forbidden actions, such as committing secrets>

## Approach
Explain the proposed solution and why it was chosen. Link to `CONTEXT.md`
for evidence and to architecture decision records (`ADR-NNN`) for decisions
that affect several steps. Do not repeat detailed requirements from SPEC.

## Visualize
Use ASCII diagrams freely when they help explain the work. Choose useful
views: system diagrams, state machines, data flows, design sketches,
dependency graphs, or comparison tables. Replace this example with diagrams
for the task. If a small task needs no diagram, state why in one sentence.

```text
+------------------------------------------+
|     Use ASCII diagrams liberally         |
+------------------------------------------+
|                                          |
|   [State A] -------> [State B]           |
|       |                                  |
|       v                                  |
|   [State C]                              |
|                                          |
|   System diagrams, state machines,       |
|   data flows, architecture sketches,     |
|   dependency graphs, comparison tables   |
|                                          |
+------------------------------------------+
```

Draw with plain ASCII only: borders `+ - |`, arrows `--> <-- ^ v`, and
markers `* x`. Keep every diagram character ASCII, including labels.
Unicode diagram glyphs can have different widths across terminals, fonts,
and locales. This can move box borders and table columns out of alignment.
Use fenced `text` blocks, not Mermaid or Unicode box glyphs.

`plan` adds an ASCII step dependency graph here if dependencies branch.
Keep useful system and behavior diagrams even if the steps are linear.

## Commands
Record the project's exact commands and flags. If a command is unavailable,
state that instead of guessing.

```text
Build: <build command>
Test:  <focused-test command>
Suite: <full-suite command>
Lint:  <lint command>
Dev:   <dev command, if any>
```

## Steps
`plan` fills this table after PRD and SPEC approval. Use one row per step in
build order. Link to each exact step filename. Keep the table in sync when
steps change; leave status and detailed actions in the step files.

| # | Step | Delivers | Files | Depends | Verify |
| - | ---- | -------- | ----- | ------- | ------ |

## Key decisions
Record each decision that affects several steps. Give a one-line reason
and a link to the evidence or interview answer.

| # | Decision | Reason | Evidence |
| - | -------- | ------ | -------- |
| D1 | <choice> | <why> | <Q3 / ADR-001 / CONTEXT.md topic> |

## Risks
List known risks that could affect the work. An approved PRD has no open
questions or unresolved assumptions. Resolve these with the user first.
