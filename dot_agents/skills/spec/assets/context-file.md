# Context — <Task Title>

This file is the discovery and provenance record behind the PRD. It captures
what was investigated, where, with which tools, what was found, and which
findings informed which decisions, so a human (or a fresh agent) debugging the
PRD can trace every requirement back to its evidence. Written during discovery
(step 1 of `spec`), refined as understanding grows, and frozen when the PRD is
approved.

| Field   | Value                 |
| ------- | --------------------- |
| Date    | YYYY-MM-DD             |
| Project | <project-full-path>    |
| Branch  | <branch>               |
| Task    | <task-name>            |
| Status  | in-progress | done       |

## Request
The feature or fix in the user's own terms, paraphrased into one paragraph.
This is the raw input before it is sharpened into the PRD's Problem.

## Codebase exploration
A topic-ordered record of what was investigated in the repo, with provenance.
Repeat the block below per topic.

### <Topic A — e.g. "how auth is wired">
- Looked at: <paths/files, with line ranges when relevant>
- Tool: <sub-agent name / rg / grep / read>
- Found: <factual findings, no interpretation>
- Implication: <what this means for the work>

### <Topic B>
- ...

## External research
Sources consulted outside the repo, each with a one-line takeaway and URL.
- [<short title>] <url> — <takeaway>

## Assumptions
Surfaced during exploration. Each has a status so a human can see at a glance
what is still open.

| #  | Assumption | Status    | Resolved by |
| -- | ---------- | --------- | ----------- |
| A1 | <…>        | validated | Q3          |
| A2 | <…>        | open      | —           |

Status values: `validated` (confirmed against code/user), `corrected` (user
overrode it), `accepted` (taken as-is), `open` (still unresolved, blocks the
PRD).

## Constraints discovered
Technical or business limits found in the code, docs, or environment
(versions, API surfaces, performance budgets, platform restrictions).

## Open questions / knowledge gaps
What is still unknown and feeds the interview. Each gap becomes a question in
`decisions.md` until resolved.

## Provenance map
The audit link: which findings informed which decisions. This is the core of
the file — it is what makes the PRD debuggable.

| Finding | → Decision |
| ------- | ---------- |
| <e.g. No existing revocation list (Topic A)> | Q5 (denylist table) |
| <…> | <Q# or ADR-NNN> |

## Notes
Anything else useful for traceability that does not fit above (e.g. prior art,
rejected directions, deferred investigations).
