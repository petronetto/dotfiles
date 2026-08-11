---
name: spec-build
description: Implement an existing plan one step at a time in small chunks, stopping after each step for explicit approval. Trigger on "build", "implement", "resume". Reads from spec-plan's output and runs the review-gated loop.
argument-hint: "[task-name]"
---

# Spec Build

Implement a plan from `spec-plan`, one step at a time, under human-in-the-loop review gates. State lives on disk; every run re-derives context from git and filesystem for clean resumption.

## Hard rules

- Implement one step at a time. Never start the next step before approval.
- Break each step into small, readable chunks (focused diffs reviewable in minutes). Prefer more, smaller chunks.
- Stop after every step. Do not continue on your own.
- Never commit without explicit, unambiguous approval (per-step).
- Never mark done or advance under uncertainty. When in doubt, ask (see `references/uncertainty-protocol.md`).
- Preserve existing behavior unless the step requires changing it.

## Procedure

### 1. Locate the plan

- Plans are in `.plans/` directory. Find the most recent `<task-name>` with `Status: pending` steps.
- If multiple candidates exist, ask which to resume. Confirm before starting.
- Read `summary.md` in that directory for the plan's problem, approach, and key decisions.

### 2. Run the loop

For each step (lowest `NNN` with `Status: pending`):

**Announce** — State the step and goal. Set `Status: in-progress`.

**Implement in chunks** — Work chunks in order, each focused and reviewable. Apply `references/code-quality.md`. Add/update tests per Verification; run linters/tests where available.

**Stop for review** — Stop when complete. Do not commit. Do not start the next step.

**Handle response**
- Modifications requested: append to Review log via `assets/review-log-entry.md`, implement changes as small chunks, stop again. Repeat as needed.
- Approved: ask "Am I cleared to commit this step and move to the next task?" on any uncertainty. Commit using project style (never co-authors), stage only this step's files. Set `Status: done`, record final message under `Commit`, move to next step.

### 3. Finish

When all steps are `Status: done`, report: summary of changes, rationale, and suggested improvements.

## References

- Code-quality standards: `references/code-quality.md`
- Uncertainty protocol: `references/uncertainty-protocol.md`
- Review log entry template: `assets/review-log-entry.md`
