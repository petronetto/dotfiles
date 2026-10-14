# Writing Good Specs

The `spec` skill turns a request into `PRD.md` and `SPEC.md` before any code
is written. The PRD explains the problem, goals, scope, and approach. The
SPEC defines the behavior that implementation must deliver and the
scenarios that will verify it. Review and refine both documents with the
user before handing approved requirements to `plan`.

This guide explains how to write requirements and scenarios that a reader
can understand and test without having to inspect the implementation.

## A spec is behavior, not code

A specification describes what the system does, not how it is built. It
contains requirements that define observable behavior and scenarios that
exercise those requirements in concrete situations.

```markdown
### Requirement: R1 - Expire inactive sessions
Goal: G1 in PRD.md.

The system SHALL expire an authenticated session after 30 consecutive
minutes without a successful authenticated request. Once the session has
expired, the user must sign in again before accessing protected resources.
A successful authenticated request before expiration restarts the
inactivity period.

#### Scenario: R1.1 - Reject a protected request after expiration
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user requests a protected resource at 09:30 without any intervening activity
- **THEN** the system rejects the request with HTTP 401 and indicates that the user must sign in again
- **AND** the response contains no protected resource data

#### Scenario: R1.2 - Restart the inactivity period after a successful request
- **GIVEN** a user whose last successful authenticated request was at 09:00
- **WHEN** the user successfully accesses a protected resource at 09:20
- **THEN** the inactivity deadline moves to 09:50
```

Keep architecture and implementation choices in the PRD's Approach section.
When a decision had real alternatives and affects several steps, record
its architecture decision record (ADR) in the optional `Architecture
decision records` section of `CONTEXT.md`. Do not create separate ADR files.
Implementation steps belong in the step files written by `plan`.

An interface name, response format, or error code belongs in SPEC when a
user or caller relies on it. An internal class name or library choice does
not belong there merely because the implementation uses it. If that detail
can change without changing observable behavior, keep it outside SPEC.

## Write complete requirements, not fragments

Use standard technical English with complete sentences and coherent
paragraphs. Preserve the conditions, definitions, and qualifications needed
to understand the rule. A requirement does not have to fit in one short
sentence, and there is no sentence-length limit.

A good requirement has these properties:

- **One observable behavior.** Keep related conditions and guarantees
  together. Split independent behaviors into separate requirements instead
  of deleting information to make a paragraph shorter.
- **Enough context to test.** Identify the actor, trigger or conditions,
  expected result, and relevant limits. For example, "The system SHALL show
  an error banner when an upload exceeds 10 MB" defines a checkable result;
  "The system SHALL handle large uploads gracefully" does not.
- **Precise obligation.** Use RFC 2119 keywords: `SHALL` or `MUST` for
  required behavior, and `SHALL NOT` or `MUST NOT` for forbidden behavior.
  Do not weaken an agreed requirement with "should" or "may".
- **Consistent terminology.** Use the same name for the same concept and
  define unfamiliar domain terms when they first appear.
- **Traceability.** Give the requirement a stable ID such as `R1` and link
  it to the PRD goal it supports. Keep detailed behavior in SPEC rather
  than repeating it in the PRD.

Ask whether someone who has never seen the code could determine whether
the requirement passed. If the answer is no, identify the missing context
or unresolved decision before trying to shorten the wording.

## Make scenarios exercise their requirements

Every requirement needs at least one scenario that demonstrates its
behavior in a specific situation. A scenario that only repeats the
requirement in other words does not establish a useful check.

Use `#### Scenario:` headings with stable IDs such as `R1.1` and descriptive
titles that name the case being tested. Within each scenario:

- `GIVEN` establishes a relevant starting state when one is needed.
- `WHEN` identifies the action, input, or event that exercises the rule.
- `THEN` states the observable outcome, including concrete values or errors
  when those are part of the behavior.
- `AND` adds a related condition or outcome without compressing several
  facts into an unclear fragment.

Cover the cases that matter, not just the successful path. Depending on the
requirement, these may include empty input, an expired token, a repeated
request, a permission failure, or an exact boundary value. Each scenario
should be specific enough to become an automated test or an explicit
manual check.

Before approval, ask which failure would matter most to the user and
confirm that a scenario covers it. Do not invent unsupported behavior to
add more scenarios; resolve material gaps with the user.

## Describe the change in the task's SPEC.md

Start every SPEC with `## Purpose`, explaining the behavior it defines and
who relies on it, with a link to `PRD.md`. Keep only the requirement groups
that apply to the task:

- **`## ADDED Requirements`** describes behavior that does not exist yet.
- **`## MODIFIED Requirements`** describes existing behavior that will
  change. Include the complete updated requirement and its scenarios, not
  just a note about the difference. Preserve conditions and guarantees
  that remain valid.
- **`## REMOVED Requirements`** identifies behavior that will no longer be
  available, explains why it is removed, and states the migration path or
  what existing callers should observe instead.

Check the current behavior and any relevant existing specifications before
choosing a group. Do not label an existing rule as new merely because this
is the first time the task documents it. Keep requirement and scenario IDs
stable when revising the document.

For a pure refactor, state `No behavior change` in both PRD and SPEC. In
SPEC, replace the requirement groups with `## Preserved behavior`, describe
what must stay the same, and list the existing checks that prove it. Do not
invent new requirements or scenarios for implementation-only work.

## Match the detail to the change

A good task has a clear intent and an explicit boundary. If its scope is a
list of unrelated features, agree on separate tasks before writing one
large specification. Keep requirements for related behavior together, but
do not expand the work to include speculative future features.

Match the amount of detail to the risk. A small fix can have a short PRD
and a SPEC with one requirement and one scenario. Security-sensitive,
compatibility-breaking, or migration-heavy changes need enough conditions
and cases to make their consequences clear. Neither case needs extra
documents just to add ceremony.

## Refine the draft with the user

Use the request to establish intent and boundaries. For example, "Add a
dark-mode toggle that follows the operating-system setting on first load,
without changing the existing theme API" identifies both the change and
what must remain untouched.

Read the code and available evidence before asking questions it can answer.
Ask the user one focused question at a time for decisions that remain
unclear. Record each answer in `decisions.md`, and keep supporting findings
and assumptions in `CONTEXT.md`. Do not guess to finish a draft.

Review the requirements for vague language, missing cases, contradictions,
and unnecessary implementation detail. If a timeout must be 30 minutes,
write that value rather than "after a while". If a scenario does not
exercise its requirement, replace it with one that does.

Stop after presenting the PRD and SPEC for approval. Only after both are
approved does `plan` turn the requirements and scenario IDs into ordered
step files and update the PRD's Steps table. The user reviews those steps
before `build` begins implementation. If planning exposes a missing or
conflicting requirement, return to `spec` for resolution and approval.

## Review checklist

- [ ] The PRD's scope matches the request and excludes unrelated work.
- [ ] SPEC uses complete, readable technical prose rather than terse fragments.
- [ ] Each requirement defines one observable behavior with enough context to test it.
- [ ] Required and forbidden behavior uses the appropriate `SHALL` or `MUST` keywords.
- [ ] Requirement and scenario IDs are stable, and each requirement links to a PRD goal.
- [ ] Every requirement has a scenario that actually exercises it.
- [ ] Important error cases and boundary conditions have scenarios.
- [ ] ADDED, MODIFIED, and REMOVED groups match the actual behavior change, or a pure refactor documents preserved behavior.
- [ ] Implementation choices are in the PRD or ADR entries in CONTEXT.md, not mixed into behavioral requirements.
- [ ] There are no unresolved assumptions or open questions.
- [ ] The user approved both PRD and SPEC before the handoff to plan.
