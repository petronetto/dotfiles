# <Task Title> - SPEC

## Purpose
Describe the behavior this specification defines, who relies on it, and
what the capability enables. Link to [PRD.md](PRD.md) for goals, scope, and
approach.

Write in standard technical English. Use complete sentences and coherent
paragraphs, with enough context for a reader who has not seen the code. Prioritize clarity and
completeness over brevity. Do not apply controlled-language rules, impose
sentence-length limits, or turn requirements into terse fragments.
Define unfamiliar domain terms when they are first used.

A specification is a behavior contract, not an implementation plan.
Describe observable behavior, inputs, outputs, error conditions, and
external constraints such as security, privacy, or compatibility. Keep
internal architecture and implementation choices in the PRD or ADR entries
in CONTEXT.md; implementation steps belong in the plan.

## Authoring guidance
Remove all template instructions from the finished document. Replace the
example below with task-specific requirements and scenarios.

### Requirements
Use RFC 2119 requirement language: `SHALL` or `MUST` for required behavior,
and `SHALL NOT` or `MUST NOT` for forbidden behavior. Each requirement
covers one observable behavior. Include the actor, relevant conditions,
expected result, and any limits needed to make the rule unambiguous.
Supporting sentences can explain scope or terminology; a requirement does
not have to fit in one short sentence. Split independent behaviors into
separate requirements rather than removing information to shorten them.

Keep only the applicable groups: `ADDED Requirements`, `MODIFIED
Requirements`, and `REMOVED Requirements`. Repeat the requirement and
scenario pattern below for each group.

- ADDED describes new behavior.
- MODIFIED includes the complete updated requirement and its scenarios,
  not just a summary of the difference. Preserve unchanged conditions and
  guarantees that still apply.
- REMOVED states the reason for removal and the migration path, including
  replacement behavior or what existing callers should observe instead.

Use stable requirement IDs (`R1`, `R2`) and scenario IDs (`R1.1`, `R1.2`).
Do not renumber existing IDs when adding requirements. Link each
requirement to its PRD goal. Do not invent behavior or implementation
details to fill the template.

### Scenarios
Give every requirement at least one scenario that exercises its behavior,
not just a restatement of the requirement. Use descriptive titles that
name the case being tested. Cover relevant success, error, and edge cases.

Use `### Requirement:` headings and `#### Scenario:` headings. Within each
scenario, use `GIVEN` for relevant initial state, `WHEN` for the action or
trigger, `THEN` for the expected result, and `AND` for related conditions or
outcomes. Use concrete inputs and observable results so each scenario can
become an automated test or an explicit manual check.

### Pure refactors
For a pure refactor, replace the requirement groups with `## Preserved
behavior`. State `No behavior change`, describe the behavior that must stay
the same, and list the existing checks that prove it. Do not invent new
requirements or scenarios.

## ADDED Requirements

### Requirement: R1 - Expire inactive sessions
Goal: [G1 - Protect access to authenticated resources](PRD.md#goals).

The system SHALL expire an authenticated session after 30 consecutive
minutes without a successful authenticated request. After expiration, the
user must sign in again before accessing protected resources. A successful
authenticated request before expiration restarts the inactivity period.

#### Scenario: R1.1 - Reject a protected request after expiration
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user requests a protected resource at 09:30 without any intervening activity
- **THEN** the system rejects the request with HTTP 401 and indicates that the user must sign in again
- **AND** the response contains no protected resource data

#### Scenario: R1.2 - Restart the inactivity period after a successful request
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user successfully accesses a protected resource at 09:20
- **THEN** the inactivity period restarts at 09:20 and the session remains valid until 09:50 unless another successful authenticated request restarts it
