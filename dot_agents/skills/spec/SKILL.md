---
name: spec
description: Write PRD.md and SPEC.md for a feature or fix before coding. Ask the user one question at a time to agree on goals and behavior. Trigger on "spec", "requirements", "design the work", "scope it first". Produces plain-language goals, ASCII diagrams, requirements, and test scenarios for `plan`; outputs Markdown only, never code.
---

# Spec

Agree on what to build and why before writing code. Write `PRD.md` (product requirements document) for goals and approach. Write `SPEC.md` (behavior specification) for required behavior and test scenarios. `plan` uses both files to write steps. Output is Markdown only; `build` handles implementation.

## Writing rules

Apply these rules to all documents, questions, and summaries:

- Write in ASD-STE100 Simplified Technical English. Use short sentences, active voice, and one main idea per sentence.
- Use common words. Write "use", not "leverage"; "evidence", not "provenance"; "affects several steps", not "cross-cutting".
- Keep technical terms only when they add precision. Define each necessary term or abbreviation at first use. Keep exact code names, paths, commands, and required format labels.
- Use one term for each concept. Avoid metaphors, idioms, vague claims, and long groups of nouns.
- State what changes, who or what acts, and the expected result. Do not make a simple task sound complex.
- Do not use em or en dashes. Use commas, colons, parentheses, or separate sentences.
- Use plain ASCII in diagrams and aligned tables. Follow the PRD template's `Visualize` instructions.

## Hard rules

- Never write or edit code; output is Markdown only.
- Ask one question at a time. Follow `~/.agents/references/question-format.md` and use the harness's question tool when available. Read the code instead of asking questions it can answer.
- Record each answer in the plan directory's `decisions.md`.
- From the first investigation, record paths, tools, findings, and their effect on decisions in `CONTEXT.md`. This evidence explains why the requirements exist.
- List assumptions and resolve them with the user before proceeding. Never guess at a requirement or design decision.
- Finished documents contain no open questions or unresolved assumptions.
- Prefer a simpler problem or solution over added complexity. Follow `~/.agents/references/code-quality.md`.
- Never delete an existing PRD, SPEC, or plan. Ask before resuming unfinished work or starting a new task.

## Gotchas

- A new task needs a new `<task-name>` slug. Do not reuse another task's directory, even if the user says "start fresh".
- Match document length to the task. A small fix still needs a short PRD (problem, goal, boundaries) and a SPEC with one requirement and scenario.
- For a pure refactor, state `No behavior change` in both files. Name the existing behavior and checks to preserve; do not invent new requirements or scenarios.

## Plan CLI

- `plan-cli` means `~/.agents/plan-adapters/plan`. Use it for every plan-file operation, not a hand-built path.
- `init <task-name>` creates or finds the task and prints its `<location>`.
- `read <location> <file>` reads a file. `write <location> <file>` and `append <location> <file>` take content on stdin, via a heredoc.
- `list` prints one `<location>` per line. `path <location>` prints its on-disk directory.
- `set-status <location> (--step <file> | --entry <id>) --status <status> [--reason <text>]` updates status. The step's `Blocked` row changes with the `blocked` status.
- `PLAN_BACKEND` selects the backend (`disk` by default). Settings live in `~/.agents/plans.config.md`. Get each `<location>` from `init` or `list`.

## Procedure

### 1. Establish context

- Get the repo path, branch, and commit style from git.
- Use sub-agents to explore enough of the codebase to plan responsibly.
- Prefer quality and simplicity over development cost.
- Record each investigation now: path, tool, finding, and effect on the work. Save this record in step 3.

### 2. Choose the plan directory

Use a short git-safe `<task-name>` (lowercase letters, digits, hyphens). Run `plan-cli init <task-name>` and call its output `<location>`. Read any existing `PRD.md` and `SPEC.md` with `plan-cli read`. If the task has unfinished work, ask whether to resume or start a new task.

### 3. Write CONTEXT.md

Fill `assets/context-file.md` into `<location>/CONTEXT.md` via `plan-cli write`. Include the request, code findings, external research, assumptions, limits, unknowns, and an evidence map that links findings to decisions. Update it as understanding grows. Mark it done when PRD and SPEC are approved.

### 4. Check assumptions

List assumptions about the platform, data, access control, target environment, and dependencies. Record them in the Assumptions table with status `open` or `accepted`. Ask the user to correct them. Update each status to `validated`, `corrected`, or `accepted` after resolution. Do not silently fill gaps.

### 5. Check the scope before the interview

Most requests cover one feature. Handle these exceptions first:

- **A whole new project:** stop and hand off to `blueprint`. It writes the project charter and roadmap. Each roadmap item returns here as a separate request.
- **Several independent features:** propose a small module table with dependencies and build order. Dependencies must have no cycles. Get approval, then write a PRD and SPEC per module in dependency order. Do not turn the table into a second project plan.

### 6. Interview the user

Ask one question at a time until all requirements and decisions are clear. Follow `~/.agents/references/question-format.md`. Append each answer to `<location>/decisions.md` via `plan-cli append`. Include an `**Evidence:**` line that links to the relevant `CONTEXT.md` topic or evidence row. Omit it only for user preferences with no supporting finding.

### 7. Record decisions that affect several steps

Create an architecture decision record (ADR) only when both conditions hold:

1. Two or more real alternatives were considered.
2. The decision affects more than one plan step.

Fill `assets/adr-file.md` into `ADR-NNN-<slug>.md`, using the next free number. Add `**Promoted to:** ADR-NNN` to the original `decisions.md` entry. Do not change an accepted decision in place. Write a replacement ADR and mark the old one superseded. Most tasks need zero to two ADRs.

### 8. Write the PRD and SPEC

Fill `assets/prd-file.md` into `<location>/PRD.md` and `assets/spec-file.md` into `<location>/SPEC.md` via `plan-cli write`.

- The PRD explains the problem, goals, excluded work, boundaries (Always / Ask first / Never), approach, commands, decisions, and risks. Give each goal an ID (`G1`, `G2`) and link it to requirements in `SPEC.md`. Keep detailed scenarios in SPEC, not in both files.
- Add a `Visualize` section to the PRD. Use ASCII diagrams freely to explain the system, states, data flow, design, or dependencies. Use comparison tables when useful. Replace the template example with task-specific content. For a small task where a diagram adds no information, state that briefly instead of adding decoration.
- SPEC defines observable behavior. Use `Purpose`, applicable `ADDED Requirements`, `MODIFIED Requirements`, or `REMOVED Requirements`, then `Requirement` and `Scenario` headings. Use stable requirement and scenario IDs.
- Use `SHALL` for a required result and `SHALL NOT` for a forbidden result. These mean "must" and "must not". Keep the rest of each sentence plain and direct.
- Give each requirement at least one concrete `WHEN`/`THEN` scenario. Add `GIVEN` when a starting condition matters. Cover relevant success, error, and edge cases. For modified behavior, state the full new rule. For removed behavior, state what replaces it or what callers should observe instead.
- Link each requirement to a PRD goal. Link each key decision to its evidence (`Q#`, `ADR-NNN`, or a `CONTEXT.md` topic). Resolve conflicts between files with the user before approval.
- Leave the PRD's Steps table for `plan` to fill. Do not create a separate flow document or delete old plan files.

### 9. Present and stop

Summarize the PRD and SPEC. List the files created: `PRD.md`, `SPEC.md`, `CONTEXT.md`, `decisions.md`, and any `ADR-NNN-*.md`. Do not implement. Hand off to `plan` only after the user approves both PRD and SPEC.

If the PRD's Roadmap field names an entry, get `<roadmap-location>` from `plan-cli init roadmap` or `plan-cli list`. Run `plan-cli set-status <roadmap-location> --entry <id> --status in-progress`. Read that `ROADMAP.md`, fill the entry's `PRD` column with this task's `<location>`, and write it back via `plan-cli write`.

## Red flags

- Writing code before the requirements are approved.
- Treating a small task as a reason to skip requirements.
- Passing an unresolved question or assumption to `plan`.
- Putting several independent features in one PRD without an approved module table.
- Repeating requirements in both PRD and SPEC, where they can disagree later.

## Verification

Before handing off to `plan`, confirm:

- [ ] The user approved both `PRD.md` and `SPEC.md`.
- [ ] All documents use ASD-STE100 Simplified Technical English; necessary technical terms are defined at first use.
- [ ] Problem, goals, and excluded work are concrete. Words such as "fast" have a number or check.
- [ ] Each PRD goal links to SPEC requirements, and each requirement links back to a goal.
- [ ] Each requirement and scenario has a stable ID. Scenarios are concrete enough to become tests and cover relevant errors and edge cases.
- [ ] A pure refactor states `No behavior change` and names preservation checks instead of new requirements.
- [ ] The PRD has a `Visualize` section with useful task-specific content or a brief reason why no diagram is needed. All diagram characters are ASCII.
- [ ] Boundaries and the project's build, test, and lint commands are recorded.
- [ ] Key decisions have a one-line reason and an evidence link.
- [ ] `CONTEXT.md` records the request, investigations, assumptions, limits, and evidence map.
- [ ] Every interview answer is in `decisions.md`, with `**Evidence:**` where applicable. Entries moved to ADRs have `**Promoted to:**` links.
- [ ] Decisions with real alternatives that affect several steps have ADRs.
- [ ] PRD, SPEC, and CONTEXT agree and contain no open questions or `open` assumptions.
- [ ] Both `PRD.md` and `SPEC.md` are saved under `<location>/`.
- [ ] Any linked roadmap entry is `in-progress` and its PRD link points here.

## References

- Question format: `~/.agents/references/question-format.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- PRD template: `assets/prd-file.md`
- Behavior specification template: `assets/spec-file.md`
- Discovery record template: `assets/context-file.md`
- ADR template: `assets/adr-file.md`
- Plan CLI: `~/.agents/plan-adapters/plan` (a bare call prints usage; settings: `~/.agents/plans.config.md`)
