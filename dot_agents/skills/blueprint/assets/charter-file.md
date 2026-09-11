# Charter — <Project Title>

The project-level constitution: what this project is, the decisions that
constrain every epic, and the provenance behind them. Written by `blueprint`
before any epic is specified. Every epic's PRD inherits from this file and
narrows its boundaries; it never widens them. Living document: changed
decisions are superseded by new ADRs, never by silent edits.

| Field   | Value                 |
| ------- | --------------------- |
| Date    | YYYY-MM-DD             |
| Project | <project-full-path>    |
| Status  | draft / active         |

## Vision
What this project is and why it exists, in the user's own terms, in one
paragraph. This is the raw input before it is sharpened into goals.

## Users
Who uses this and what job it does for them. One or two lines per user.

## Goals
What the project must achieve to count as done. Concrete and testable.

## Non-goals
Explicitly excluded work that looks related but is out of scope for the whole
project, not just one epic.

## Hard constraints
Non-negotiable limits found or imposed: platform, deployment target, privacy,
licenses, performance budgets, supported versions.

## Stack decisions
The choices that constrain every epic. Each entry carries a one-line
rationale; decisions with real alternatives and cross-epic reach are promoted
to `ADR-NNN-*.md` next to this file and linked here.

| #  | Decision | Choice | Rationale | Traceability |
| -- | -------- | ------ | --------- | ------------ |
| S1 | <…>      | <…>    | <one line> | Q# / ADR-NNN |

## Project boundaries
Three tiers, project-wide. Each epic's PRD narrows these; it never widens them.
- **Always do:** ... (e.g. run the test suite before each epic's handoff, follow the layout below)
- **Ask first:** ... (e.g. new runtime dependencies, schema changes, third-party services)
- **Never do:** ... (e.g. commit secrets, bypass CI, ship without tests)

## Layout and test strategy
Where code lives (directory conventions, naming) and how behavior is tested,
so every PRD writes the same Commands section instead of re-deciding.

## Research
Sources consulted outside the repo, each with a one-line takeaway. Findings
that informed a decision carry their traceability link in the tables above.
- [<short title>] <url> — <takeaway>

## Assumptions
Surfaced during discovery. Each has a status so a human can see what is open.

| #  | Assumption | Status    | Resolved by |
| -- | ---------- | --------- | ----------- |
| A1 | <…>        | validated | Q3          |

Status values: `validated` (confirmed with the user or research), `corrected`
(user overrode it), `accepted` (taken as-is), `open` (unresolved; an open
assumption blocks the roadmap).

## Open questions
What is still unknown and belongs to a later epic's spec, not to this charter.