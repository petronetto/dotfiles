### ADR-NNN

**Title:** <Decision title>

This is an entry template for the `Architecture decision records` section
of `CONTEXT.md`, not a standalone file. An architecture decision record
(ADR) explains a choice that had at least two real alternatives and affects
more than one plan step (or more than one epic for a blueprint). Otherwise,
keep the choice in `DECISIONS.md` and link to its Q-number from the PRD
or charter.

Use the next free ADR-NNN number in this `CONTEXT.md`. Keep the heading
exactly `### ADR-NNN` so its link stays stable. Project, Branch, and Task
come from the containing document; do not repeat them in each entry.
Do not change an accepted decision in place. Add a replacement entry, then
update only this entry's Status and Superseded by fields.

Write in ASD-STE100 Simplified Technical English. Use common words and
define necessary technical terms. Remove template instructions when done.

| Field | Value |
| ----- | ----- |
| Date | YYYY-MM-DD |
| Status | proposed / accepted / superseded |
| Supersedes | <[ADR-NNN](#adr-nnn), or none> |
| Superseded by | <[ADR-NNN](#adr-nnn), or none> |

#### Context
State the problem, limits, and relevant findings. Link to the specific
`CONTEXT.md` topic or evidence row (or `CHARTER.md` research for a blueprint).
Link to the PRD or charter rather than repeating it.

#### Decision
The choice, in one active-voice sentence. State what was chosen, not what was
rejected.

#### Alternatives considered
Each real alternative with a one-line summary and why it was rejected. These
must be genuine options that were on the table, not strawmen.

- **Alternative A: <option>** Rejected because <reason>.
- **Alternative B: <option>** Rejected because <reason>.

#### Consequences
State benefits, drawbacks, and new risks. Include what a maintainer needs
to know before changing or reversing this decision.

#### Related
Links to the `DECISIONS.md` Q-number(s) this promotes, the findings that
informed it, and any step files or other ADR entries it interacts with.
Link to other ADR entries by their headings, not by separate filenames.
