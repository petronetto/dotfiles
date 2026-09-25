---
name: build
description: Implement an existing plan one step at a time in small chunks, stopping after each step for explicit approval. Trigger on "build", "implement", "resume". Reads `plan`'s step files and runs the review-gated, test-driven loop.
---

# Build

Implement a plan from `plan`, one step at a time, under human-in-the-loop review gates. State lives on disk; every run re-derives context from git and the filesystem for clean resumption. Each step is test-driven before it counts as done.

## Hard rules

- Implement one step at a time. Never start the next step before approval.
- Break each step into small, readable chunks (focused diffs reviewable in minutes). Prefer more, smaller chunks, but every chunk must deliver a working change on its own, no scaffolding-only chunks (e.g. enums nothing consumes yet).
- Test behavior, not implementation (AAA, mock external dependencies). Add or update tests per each step's Verification before considering it done; run the project's tests and linters where available. The discipline lives in the `test` skill.
- Stop after every step. Do not continue on your own.
- Never commit without explicit, unambiguous approval (per step).
- Never reference the plan, steps, or chunks in commit messages or code comments; describe the actual change so the message stands alone.
- Never mark done or advance under uncertainty. When in doubt, ask (see `~/.agents/references/uncertainty-protocol.md`). Ask multi-option decisions (which plan to resume, resume vs restart a step) per `~/.agents/references/question-format.md`, appending each answer to the plan directory's `decisions.md`.
- Preserve existing behavior unless the step requires changing it.

## Gotchas

- A chunk that only adds scaffolding (an enum, a type, a stub nothing consumes yet) doesn't count as a chunk — every chunk must leave the codebase working end-to-end, however small.

## Plan CLI

- `plan-cli` below means `~/.agents/plan-adapters/plan`. Every plan-file
  operation goes through it, never through a hand-built path: `init
  <task-name>` (prints the task's `<location>`, idempotent), `read
  <location> <file>`, `write <location> <file>` and `append <location>
  <file>` (content on stdin, via heredoc), `list` (one `<location>` per
  line), `set-status <location> (--step <file> | --entry <id>) --status
  <status> [--reason <text>]` (the step's `Blocked` row moves in lockstep
  with `blocked`), and `path <location>` (the `<location>`'s on-disk
  directory).
- `PLAN_BACKEND` selects the backend (`disk` by default); its settings
  live in `~/.agents/plans.config.md`. Every `<location>` comes from
  `init` or `list` output.

## Procedure

### 1. Locate the plan
- Run `plan-cli list` to enumerate the task directories; each printed line is that task's `<location>`. For each candidate, run `plan-cli read <location> FLOW.md` to get its step file names, then `plan-cli read` each step file, and find the most recent `<location>` with `Status: pending`, `in-progress`, or `blocked` steps: `in-progress` means a prior session was interrupted mid-step; `blocked` means a prior `build-auto` run left it unresolved after 3 review cycles.
- If multiple candidates exist, ask which to resume. Confirm before starting.
- Run `plan-cli read <location> PRD.md` for the plan's problem, approach, and key decisions.

### 2. Run the loop
For each step (lowest `NNN` not yet `Status: done`):

- If `Status: in-progress`, an earlier session was interrupted mid-step. Show the step file and the current diff, and ask the user whether to resume from where it left off or restart the step from a clean tree — never silently skip it for the next pending step.
- If `Status: blocked`, a prior `build-auto` run left it unresolved. Show the step file's `Blocked` reason and review log, then work it through the same loop below until it resolves.
- If `Status: pending`, proceed as normal below.

**Announce** — State the step and goal. Run `plan-cli set-status <location> --step <step-file> --status in-progress`.

**Implement in chunks** — Work chunks in order, each focused and reviewable. Apply `~/.agents/references/code-quality.md`. Run new code through the reuse/YAGNI gate (`~/.agents/references/reuse-checklist.md`). Add or update tests per Verification, then run linters/tests where available, piping long output.

**Stop for review** — Stop when complete. Do not commit. Do not start the next step.

**Handle response**
- Modifications requested: append to the review log (`plan-cli append <location> <step-file>`) in the `assets/review-log-entry.md` format, implement the changes as small chunks, stop again. Repeat as needed.
- Approved: ask "Am I cleared to commit this step and move to the next task?" on any uncertainty. Commit using project style (never co-authors), staging only this step's files. Run `plan-cli set-status <location> --step <step-file> --status done`, then record the final commit message under the step file's `Commit` section: `plan-cli read` the file, fill the section, write it back via `plan-cli write`. Move to the next step.

### 3. Finish
When all steps are `Status: done`, run the acceptance audit before reporting:

**Audit the delivered work against the PRD** — Re-read the PRD's goals and scenarios and check each against the code as delivered, not the step logs: completion claims are not evidence. Classify every gap as `missing` (required work absent), `partial` (present but short of the scenario), `contradicts` (conflicts with the PRD or a boundary), or `unrequested` (work the PRD never asked for; surface it for review, don't delete it). Work gaps through the same loop as review modifications: move the affected step back to `in-progress` (`plan-cli set-status <location> --step <step-file> --status in-progress`), append to its review log, implement as small chunks, stop for approval, repeat until no gap remains. A pure refactor (`No behavior change`) audits against preserved behavior instead.

Then report: summary of changes, rationale, and suggested improvements. If the PRD's Roadmap field names an entry in the `roadmap` task's `ROADMAP.md`, run `plan-cli set-status <roadmap-location> --entry <id> --status done` with the `roadmap` task's `<location>`, its entry from step 1's enumeration, before reporting.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "I'll test it all at the end." | Bugs compound. A bug in step 1 makes steps 2-5 wrong. Test each step. |
| "It's faster to do it all at once." | It feels faster until something breaks and you can't tell which change did it. |
| "This chunk is too small to keep separate." | Small, working chunks are free. A big, messy one hides bugs and makes rollback painful. |
| "I'll add the regression test later." | A bug fix without a reproduction test is not a fix. Add it now (see `test`). |
| "All steps passed, so the PRD is satisfied." | Per-step verification proves each step, not the whole contract; the acceptance audit closes the loop between spec and implementation. |

## Red flags

- Moving to the next step without approval.
- A chunk that leaves the codebase non-working.
- Committing without unambiguous per-step approval.
- Step changes that don't carry a passing test.
- Unrelated cleanup or refactors snuck into a step.
- Reporting all steps done without auditing the delivered work against the PRD.

## Verification

Before a step counts as done:
- [ ] The step's tests exist and pass; linters pass.
- [ ] Behavior was verified at runtime, not just compiled or typechecked.
- [ ] Scope was held to the step file; no unrelated changes.
- [ ] The Definition of Done (`~/.agents/references/definition-of-done.md`) is satisfied, not just the step's own acceptance criteria.
- [ ] The user approved the step, and it was committed with only its files staged.

Before the plan counts as finished:
- [ ] The acceptance audit ran; the delivered work matches the PRD's goals and scenarios with no `missing`, `partial`, `contradicts`, or `unrequested` gap outstanding.

## References

- Definition of Done: `~/.agents/references/definition-of-done.md`
- Code-quality standards: `~/.agents/references/code-quality.md`
- Reuse/YAGNI gate: `~/.agents/references/reuse-checklist.md`
- Uncertainty protocol: `~/.agents/references/uncertainty-protocol.md`
- Question format and decision log: `~/.agents/references/question-format.md`
- Review log entry template: `assets/review-log-entry.md`
- Test discipline: `test` skill · autonomous variant: `build-auto` skill
- Plan CLI: `~/.agents/plan-adapters/plan` (a bare call prints usage; backend settings: `~/.agents/plans.config.md`)
