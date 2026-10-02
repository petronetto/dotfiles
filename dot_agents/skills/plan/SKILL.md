---
name: plan
description: Break approved PRD.md and SPEC.md files into small, ordered steps before coding. Trigger on "plan", "break down", "decompose the spec". Writes plain-language step files and updates the PRD's Steps table and ASCII dependency diagrams; outputs Markdown only, never code.
---

# Plan

Turn approved goals and requirements into small steps that are easy to review. Read `PRD.md` for goals and approach, and `SPEC.md` for behavior and test scenarios. If either is missing, run `spec` first. `build` handles implementation. Read git and the saved plan files on each run; do not rely on session memory.

## Hard rules

- Never write or edit code; output is Markdown only.
- Give each step one responsibility. Each step must leave the codebase working.
- Read `CONTEXT.md` for the evidence behind decisions. Treat each linked architecture decision record (`ADR-NNN-*.md`) as the accepted record for its decision.
- Link to goals, requirements, and decisions instead of repeating them.
- Prefer a simpler solution over added complexity. Follow `~/.agents/references/code-quality.md`.
- Never delete an existing plan. Ask before resuming or starting a new task.
- Resolve all questions and assumptions with the user before writing a step.
- Do not change approved goals or behavior while planning. Return to `spec` if a requirement is missing or conflicts with another requirement.

## Writing rules

Apply these rules to step files, PRD updates, questions, and summaries:

- Write in ASD-STE100 Simplified Technical English. Use short sentences, active voice, and one main idea per sentence.
- Use common words. Write "use", not "leverage"; "evidence", not "provenance"; "build order", not "execution topology".
- Define necessary technical terms and abbreviations at first use. Keep exact code names, paths, commands, and required format labels.
- Use one term for each concept. Avoid metaphors, idioms, vague claims, and long groups of nouns.
- Do not use em or en dashes. Use commas, colons, parentheses, or separate sentences. Use ASCII only in diagrams and aligned tables.
- Start each Chunks row with a verb. Give it one action and name its files.
- State an observable result, not a design summary. Put details of how it works in "Done when" only if needed. Link to `decisions.md` for reasons.
- Use one sentence per table cell. Do not add pseudo-code unless the algorithm itself is the required result.
- State each fact once: changes in Chunks, commands in Verify, completion conditions in Acceptance. The PRD's Steps table is a short index, not a copy of step details.
- Link Verify checks to SPEC requirement and scenario IDs and the related PRD goal. Do not invent behavior to test. For a pure refactor, link to SPEC's preservation checks.
- Keep each step to about 30 content lines, excluding Review log and Commit. Split a step that needs more space.

## Gotchas

- A new task needs a new `<task-name>` slug. Do not overwrite another task's steps.
- A step that adds unused types, enums, or other unused structures is not valid. Each step must deliver a working, testable change.
- A small task may need only one step. Do not invent steps to fill a table.
- Older plans may lack SPEC or a PRD Steps table. Ask before updating them. Use `spec` to extract existing requirements into SPEC for approval; do not invent requirements or delete old files.

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

### 2. Locate or create the plan directory

Run `plan-cli init <task-name>` and call its output `<location>`. Read `PRD.md`, `SPEC.md`, `CONTEXT.md`, and each ADR linked by the PRD through `plan-cli read`.

If PRD or SPEC is missing or unapproved, stop and offer to run `spec`. If unfinished steps exist, ask whether to resume or start a new task. Follow `~/.agents/references/question-format.md` and use the harness's question tool when available. Append answers to `decisions.md`, with an `**Evidence:**` link to `CONTEXT.md` when applicable.

If `plan-cli list` shows a `roadmap` location, read its `CHARTER.md`. Keep every step inside its project-wide boundaries (Always / Ask first / Never).

### 3. Break the work into ordered steps

Give each step one responsibility. It must be possible to review and revert each step on its own, and the codebase must work after each step. Record real dependencies in `Depends`. Steps with no dependency between them can run in parallel if they do not conflict. Do not add steps that only create unused structures.

### 4. Write one file per step

Fill `assets/step-file.md` into `NNN-<step-name>.md`, with numbers starting at `000`. Write each file with `plan-cli write <location> NNN-<step-name>.md`. Follow the Writing rules. Cover all approved requirements and scenarios across the steps.

### 5. Update the PRD overview

Read `PRD.md`, then update its `Steps` table via `plan-cli write`. Use one row per step with these columns: `#`, `Step`, `Delivers`, `Files`, `Depends`, `Verify`. The Step cell links to the exact step filename. Keep rows in build order, with dependencies before the steps that need them. Update the table when steps are added, split, or reordered. Step files remain the source for status and details.

Keep system and behavior diagrams in the PRD's `Visualize` section. Add or update an ASCII dependency diagram there when steps branch. Omit that dependency diagram for a linear plan; keep other useful diagrams. Use the PRD template's ASCII rules. Do not create a separate flow document or delete existing plan files. Do not change the PRD's approved scope or decisions.

### 6. Present and stop

Show the PRD's Steps table for review, then list the files created or updated. Do not implement. Hand off to `build` only after approval.

## Red flags

- Writing code before the user approves the steps.
- A step that says only "implement the feature", with no checkable result.
- Missing dependencies or a step that leaves the codebase broken.
- Requirements repeated in steps instead of linked to SPEC.
- Steps that omit an approved requirement or test a behavior that was never agreed.

## Verification

Before handing off to `build`, confirm:

- [ ] Both `PRD.md` and `SPEC.md` are approved.
- [ ] All new text follows ASD-STE100 Simplified Technical English, with necessary terms defined and unnecessary jargon removed.
- [ ] Every step's Verify checks link to SPEC requirements and scenarios, or preservation checks for a pure refactor.
- [ ] Every approved requirement and scenario is covered by at least one step.
- [ ] Steps stay inside the charter's boundaries, when a charter exists.
- [ ] Each step has Delivers, Out of scope, Chunks with files and Done when, Verify, and Acceptance.
- [ ] Facts are not repeated across step sections; check at least one step.
- [ ] The PRD's Steps table has one row per step, with valid file links and matching dependencies.
- [ ] Diagrams in `Visualize` use only ASCII. Any step dependency diagram matches the step files.
- [ ] Each step has a test, build command, or exact manual check. Checks confirm that the codebase still works after that step alone.
- [ ] Checks cover the Definition of Done (`~/.agents/references/definition-of-done.md`), not only the step's own conditions.
- [ ] Dependencies are recorded and independent steps are identified. No step only adds unused structures.
- [ ] No step has an open question or unresolved assumption.
- [ ] The user reviewed and approved the plan.

## References

- Definition of Done: `~/.agents/references/definition-of-done.md`
- Question format: `~/.agents/references/question-format.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- Step template: `assets/step-file.md`
- PRD template: `../spec/assets/prd-file.md`
- SPEC template: `../spec/assets/spec-file.md`
- Plan CLI: `~/.agents/plan-adapters/plan` (a bare call prints usage; settings: `~/.agents/plans.config.md`)
