# ADR-NNN - <Decision title>

An architecture decision record (ADR) explains a choice that affects more
than one step and had at least two real alternatives. Otherwise, keep the
choice in `decisions.md` and link to its Q-number from the PRD.

Do not change an accepted decision in place. Write a replacement ADR, then
update this record's Status and Superseded by fields. Use the next free
ADR-NNN number in the directory.

Write in ASD-STE100 Simplified Technical English. Use common words and
define necessary technical terms. Remove template instructions when done.

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
State the problem, limits, and relevant findings from `CONTEXT.md`.
Link to the specific topic or evidence row. Link to the PRD rather than
repeating it.

## Decision
The choice, in one active-voice sentence. State what was chosen, not what was
rejected.

## Alternatives considered
Each real alternative with a one-line summary and why it was rejected. These
must be genuine options that were on the table, not strawmen.

- **Alternative A: <option>** Rejected because <reason>.
- **Alternative B: <option>** Rejected because <reason>.

## Consequences
State benefits, drawbacks, and new risks. Include what a maintainer needs
to know before changing or reversing this decision.

## Related
Links to the `decisions.md` Q-number(s) this promotes, the `CONTEXT.md`
findings that informed it, and any step files or other ADRs it interacts with.
