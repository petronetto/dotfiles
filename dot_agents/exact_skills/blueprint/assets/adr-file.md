### ADR-NNN

**Title:** <Decision title>

This entry belongs in the Architecture decision records section of the
blueprint's `CONTEXT.md`, not a standalone file. Use it only when at least
two real alternatives were considered and the decision constrains several
epics. Otherwise keep the choice in `DECISIONS.md` and link its question
number from the charter.

Use the next free ADR-NNN number and keep the heading stable. Project
metadata belongs to the containing document. Never change an accepted
decision in place: add a replacement, then update only the old Status and
Superseded by fields. Use ASD-STE100 and remove template guidance when done.

| Field | Value |
| ----- | ----- |
| Date | YYYY-MM-DD |
| Status | proposed / accepted / superseded |
| Supersedes | <[ADR-NNN](#adr-nnn), or none> |
| Superseded by | <[ADR-NNN](#adr-nnn), or none> |

#### Context
State the problem and limits. Link to `CHARTER.md` research or the relevant
context topic rather than repeat it.

#### Decision
State the chosen option in one active-voice sentence.

#### Alternatives considered
List genuine options and why they were rejected, not invented alternatives.

- **<Option>**: <reason rejected>.

#### Consequences
State benefits, drawbacks, risks, and what a maintainer must know before
reversing this choice.

#### Related
Link to the `DECISIONS.md` question this promotes, supporting research,
affected epics, and other ADR headings. Do not link separate ADR files.
