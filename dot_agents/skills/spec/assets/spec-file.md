# <Task Title> - SPEC

## Purpose
State the behavior this specification defines and who needs it. Link to
[PRD.md](PRD.md) for goals, scope, and approach.

Write in ASD-STE100 Simplified Technical English. Use short, direct
sentences. Define necessary technical terms at first use. `SHALL` means
"must"; `SHALL NOT` means "must not".

Keep only the applicable groups: `ADDED Requirements`, `MODIFIED
Requirements`, and `REMOVED Requirements`. Repeat the requirement and
scenario pattern below for each group. Use stable IDs (`R1`, `R2`, and
`R1.1`, `R1.2`); do not renumber existing IDs when adding requirements.
Each requirement links to a PRD goal. Each scenario states an observable
result, with concrete inputs and expected outputs where possible.

For modified behavior, state the full new rule. For removed behavior,
state what replaces it or what callers should observe instead. Cover
relevant success, error, and edge cases. Add `GIVEN` only when a starting
condition matters. Do not invent implementation details or requirements.

For a pure refactor, replace the requirement groups with `## Preserved
behavior`. State `No behavior change`, name what must stay the same, and
list the existing checks that prove it. Do not invent new scenarios.

Remove these template instructions from the finished document.

## ADDED Requirements

### Requirement: R1 - <Short behavior name>
Goal: <PRD.md link to G1>.

The <actor or system> SHALL <observable result and limits>.

#### Scenario: R1.1 - <Successful result>
- **GIVEN** <relevant starting condition, omit if unnecessary>
- **WHEN** <concrete action or input>
- **THEN** <observable result>

#### Scenario: R1.2 - <Error or edge case>
- **WHEN** <invalid input or boundary condition>
- **THEN** <expected result, including what must not happen>
