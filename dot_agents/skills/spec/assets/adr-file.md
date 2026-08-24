# ADR-NNN — <Decision title>

A standalone record for a durable, cross-cutting decision that constrains
multiple plan steps and had real alternatives worth recording. Promote a
`decisions.md` entry into an ADR only when the decision meets both tests:
(a) two or more genuine alternatives were considered, and (b) it affects more
than one step. Otherwise the decision stays a `decisions.md` entry; the PRD's
"Key decisions" links to the Q-number directly.

Immutable once Accepted except for the Status and Superseded-by fields; to
change the decision, write a new ADR that supersedes this one, then mark this
one superseded. Number ADRs sequentially from the highest existing ADR-NNN
in the directory.

| Field    | Value                 |
| -------- | --------------------- |
| Date     | YYYY-MM-DD             |
| Status   | proposed / accepted / superseded |
| Project  | <project-full-path>    |
| Branch   | <branch>               |
| Task     | <task-name>            |
| Supersedes | <ADR-NNN, or none>   |
| Superseded by | <ADR-NNN, or none> |

## Context
The forces that necessitate this decision: the problem, constraints, and
relevant findings from `CONTEXT.md` (link the specific topic/provenance row).
Do not restate the whole PRD; link to it.

## Decision
The choice, in one active-voice sentence. State what was chosen, not what was
rejected.

## Alternatives considered
Each real alternative with a one-line summary and why it was rejected. These
must be genuine options that were on the table, not strawmen.

- **Alternative A — <…>** Rejected because <…>.
- **Alternative B — <…>** Rejected because <…>.

## Consequences
Positive and negative impacts, trade-offs accepted, and risks introduced.
Include anything a future maintainer would need to know before reverting or
extending this decision.

## Related
Links to the `decisions.md` Q-number(s) this promotes, the `CONTEXT.md`
findings that informed it, and any step files or other ADRs it interacts with.
