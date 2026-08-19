---
name: build
description: Implement an existing plan one step at a time in small chunks, stopping after each step for explicit approval. Trigger on "build", "implement", "resume". Reads `plan`'s step files and runs the review-gated, test-driven loop.
argument-hint: "[task-name]"
---

# Build

Implement a plan from `plan`, one step at a time, under human-in-the-loop review gates. State lives on disk; every run re-derives context from git and the filesystem for clean resumption. Each step is test-driven before it counts as done.

## Hard rules

- Implement one step at a time. Never start the next step before approval.
- Break each step into small, readable chunks (focused diffs reviewable in minutes). Prefer more, smaller chunks, but every chunk must deliver a working change on its own, no scaffolding-only chunks (e.g. enums nothing consumes yet).
- Test behavior, not implementation (AAA, mock external dependencies). Add or update tests per each step's Verification before considering it done; run the project's tests and linters where available. The discipline lives in the `test` skill.
- Stop after every step. Do not continue on your own.
- Never commit without explicit, unambiguous approval (per step).
- Never reference the plan, steps, or chunks in commit messages or code comments; plans are not committed, so the reference is meaningless.
- Never mark done or advance under uncertainty. When in doubt, ask (see `references/uncertainty-protocol.md`).
- Preserve existing behavior unless the step requires changing it.

## Procedure

### 1. Locate the plan
- Plans are in the `.plans/` directory. Find the most recent `<task-name>` with `Status: pending` steps.
- If multiple candidates exist, ask which to resume. Confirm before starting.
- Read `summary.md` in that directory for the plan's problem, approach, and key decisions.

### 2. Run the loop
For each step (lowest `NNN` with `Status: pending`):

**Announce** — State the step and goal. Set `Status: in-progress`.

**Implement in chunks** — Work chunks in order, each focused and reviewable. Apply `references/code-quality.md`. Run new code through the reuse/YAGNI gate (`references/reuse-checklist.md`). Add or update tests per Verification, then run linters/tests where available, piping long output.

**Stop for review** — Stop when complete. Do not commit. Do not start the next step.

**Handle response**
- Modifications requested: append to the review log via `assets/review-log-entry.md`, implement the changes as small chunks, stop again. Repeat as needed.
- Approved: ask "Am I cleared to commit this step and move to the next task?" on any uncertainty. Commit using project style (never co-authors), staging only this step's files. Set `Status: done`, record the final message under `Commit`, move to the next step.

### 3. Finish
When all steps are `Status: done`, report: summary of changes, rationale, and suggested improvements.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "I'll test it all at the end." | Bugs compound. A bug in step 1 makes steps 2-5 wrong. Test each step. |
| "It's faster to do it all at once." | It feels faster until something breaks and you can't tell which change did it. |
| "This chunk is too small to keep separate." | Small, working chunks are free. A big, messy one hides bugs and makes rollback painful. |
| "I'll add the regression test later." | A bug fix without a reproduction test is not a fix. Add it now (see `test`). |

## Red flags

- Moving to the next step without approval.
- A chunk that leaves the codebase non-working.
- Committing without unambiguous per-step approval.
- Step changes that don't carry a passing test.
- Unrelated cleanup or refactors snuck into a step.

## Verification

Before a step counts as done:
- [ ] The step's tests exist and pass; linters pass.
- [ ] Behavior was verified at runtime, not just compiled or typechecked.
- [ ] Scope was held to the step file; no unrelated changes.
- [ ] The user approved the step, and it was committed with only its files staged.

## References

- Code-quality standards: `references/code-quality.md`
- Reuse/YAGNI gate: `references/reuse-checklist.md`
- Uncertainty protocol: `references/uncertainty-protocol.md`
- Review log entry template: `assets/review-log-entry.md`
- Test discipline: `test` skill · autonomous variant: `build-auto` skill
