# Writing specs

A specification describes observable behavior, not how the system is built.
Write delta specs at `specs/<capability-path>/spec.md` through `plan-cli`.
Use the selected schema and `../plan-adapters/change-workflow.md` for storage.

## Write complete requirements

Use standard technical English, complete sentences, and coherent paragraphs.
Do not apply controlled-language or sentence-length limits. Keep enough
context for a reader who has not seen the code to check the behavior.

Each requirement defines one observable behavior. State the actor, condition,
result, and relevant limits. Split independent behaviors rather than remove
information to shorten a paragraph. Define unfamiliar terms at first use and
use one term for each concept.

Use `SHALL` or `MUST` for required behavior, and `SHALL NOT` or `MUST NOT` for
forbidden behavior. Do not weaken requirements with "should" or "may".
Every requirement has a `Goal: G1` line linking it to a goal in `proposal.md`.
Keep detailed behavior here, not repeated in the proposal.

Requirement and scenario names are the stable IDs. Add no numeric IDs.
Preserve names when revising content. Rename only through RENAMED, with an
explicit FROM:/TO: mapping; identify the parent requirement for a scenario
rename. Do not silently rename a scenario while modifying its requirement.

An interface name, response format, or error code belongs here when callers
rely on it. Internal classes, libraries, or algorithms do not. If a detail
can change without changing observable behavior, keep it in `design.md`
when applicable, not in a requirement.

## Exercise requirements with scenarios

Every ADDED or MODIFIED requirement needs at least one concrete scenario.
Scenarios must exercise behavior, not restate the requirement. Use descriptive
`#### Scenario:` names, with:

- `GIVEN`: the relevant starting state.
- `WHEN`: the action, input, or event.
- `THEN`: the observable outcome, with concrete values or errors.
- `AND`: related conditions or outcomes, when needed.

Cover important success, error, and boundary cases. Consider empty input,
expired credentials, repeated requests, denied access, and exact limits.
Each scenario must be suitable for an automated test or an exact manual check.
Do not invent unsupported behavior to increase the number of scenarios.

```markdown
### Requirement: Expire inactive sessions
Goal: G1 (proposal.md#goals).

The system SHALL expire an authenticated session after 30 consecutive
minutes without a successful authenticated request. After expiration,
protected resources require a new sign-in. A successful authenticated
request before expiration restarts the inactivity period.

#### Scenario: Reject a protected request at expiration
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user requests a protected resource at 09:30 without intervening activity
- **THEN** the system responds with HTTP 401 and requires sign-in
- **AND** the response contains no protected resource data

#### Scenario: Restart the inactivity period after successful access
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user successfully accesses a protected resource at 09:20
- **THEN** the inactivity deadline moves to 09:50
```

## Describe the delta

Read current behavior and the main-spec baseline before choosing an operation.
Preserve the capability's full path. New capabilities start with `## Purpose`;
existing-capability deltas do not replace the baseline Purpose.

- `## ADDED Requirements`: behavior that does not exist yet.
- `## MODIFIED Requirements`: the complete updated requirement and all its
  scenarios, including unchanged guarantees. A summary of the difference is
  not enough.
- `## REMOVED Requirements`: the existing name, reason, and migration path,
  including what callers observe instead. Do not invent scenarios for removed
  behavior; use the baseline body and scenarios when checking its removal.
- `## RENAMED Requirements`: FROM:/TO: names with unchanged behavior. If behavior
  also changes, include the complete updated requirement under MODIFIED.

For a pure refactor, set `skip_specs: true` in `.change.yaml` and create no
spec output. The proposal states `No behavior change`, names the preserved
behavior, and lists the checks that prove it. Do not invent requirements.

## Match detail to risk

Keep the scope cohesive and exclude unrelated work. A small fix can need one
requirement and one scenario. Security, compatibility, or migration changes
need enough conditions and cases to make their consequences clear. Do not
add documents just for ceremony.

Read code and evidence before asking factual questions. Ask only about
material ambiguity. Record minor assumptions in the relevant existing
artifact. Keep other decisions in the conversation, except the technical
choices and rationale that belong in the schema's `design.md`.

Before saving, check for vague language, missing cases, contradictions, and
implementation details. Verify goal links, stable names, normative keywords,
and meaningful error and boundary coverage. Resolve material gaps rather
than guessing. Use ASCII only in diagrams and no em or en dashes.
