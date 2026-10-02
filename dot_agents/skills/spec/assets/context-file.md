# Context - <Task Title>

Record the evidence behind PRD.md and SPEC.md. State what was checked,
where, with which tools, what was found, and which decisions used it.
Start this record during discovery. Update it as understanding grows.
Mark it done when PRD and SPEC are approved.

Write in ASD-STE100 Simplified Technical English. Use common words and
define necessary technical terms. Remove template instructions when done.

| Field | Value |
| ----- | ----- |
| Date | YYYY-MM-DD |
| Project | <project-full-path> |
| Branch | <branch> |
| Task | <task-name> |
| Status | in-progress / done |

## Request
Restate the user's request in one short paragraph, using their terms.

## Codebase exploration
Group findings by topic. Repeat this block for each topic.

### <Topic, such as how sign-in works>
- Looked at: <paths and files, with line ranges when useful>
- Tool: <sub-agent name / rg / grep / read>
- Found: <facts, not guesses>
- Effect on the work: <what the finding means for this task>

## External research
List sources from outside the repo, with a short finding and URL.
- <source title>: <URL>, <finding>

## Assumptions
Record assumptions and update their status as they are resolved.

| # | Assumption | Status | Resolved by |
| - | ---------- | ------ | ----------- |
| A1 | <assumption> | validated | Q3 |
| A2 | <assumption> | open | none |

Status values: `validated` (confirmed by code or the user), `corrected`
(changed by the user), `accepted` (accepted as stated), `open` (unresolved).
Resolve all `open` rows before approval.

## Constraints discovered
Record technical or business limits found in code, docs, or the environment.
Examples: supported versions, response-time limits, or platform restrictions.

## Open questions / knowledge gaps
List unknowns during discovery. Turn each into a question in `decisions.md`.
Resolve them before marking this file done; no open questions may remain.

## Evidence map
Link findings to the decisions they support.

| Finding | Decision |
| ------- | -------- |
| <finding and topic link> | <Q# or ADR-NNN> |

## Notes
Record other useful evidence, rejected options, or work left for later.
