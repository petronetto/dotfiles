---
name: spec-build
description: Implement an existing plan one step at a time in small reviewable chunks, stopping after every step for explicit human approval before committing and advancing. Use when the user asks to build, implement, execute, or resume a plan, or says "build", "implement", "resume", "resume plan", or "start building". Reads step files from the plan directory produced by spec-plan and runs the review-gated implementation loop.
argument-hint: "[task-name]"
---

# Spec Build

Implement a plan produced by `spec-plan`, one step at a time, under a strict human-in-the-loop review gate.

State lives on disk in the step files, not in the conversation. Every run re-derives its context from git and the filesystem, so it resumes cleanly in any session.

## Hard rules

- Implement exactly one step at a time. Never start the next step before the current one is approved.
- Break each step into small chunks — a focused diff a human can read in a couple of minutes. Prefer more, smaller chunks.
- Stop after every step and hand control back. Do not continue on your own.
- Never commit unless the user explicitly and unambiguously approves. Approval is per-step.
- Never mark a step done or advance under any uncertainty. When in doubt, stop and ask. See `references/uncertainty-protocol.md`.
- Preserve existing behavior unless the step explicitly requires changing it.

## Procedure

### 1. Locate the plan

- `git rev-parse --show-toplevel` and `git rev-parse --abbrev-ref HEAD` → derive `<project>` and `<branch>`.
- List `$HOME/.agents/plans/<project>/<branch>/` and find the most recent `<task-name>` directory with `Status: pending` step files.
- If multiple candidates exist, present them and ask which to resume. Confirm the plan with the user before starting.

### 2. Run the loop

Repeat for each step in order, starting from the lowest `NNN` with `Status: pending`.

**Announce** — State which step file you are implementing and its goal. Set its `Status` to `in-progress`.

**Implement in chunks** — Work the step's chunks in order, each focused and easy to review. Apply `references/code-quality.md` while coding. Add/update tests per the step's Verification section and run linters/tests where available, piping long output.

**Stop for review** — When the chunks are complete, stop and clearly say the step is ready for review and you are waiting. Do not commit. Do not start the next step.

**Handle the response**
- Modifications requested: append a block using `assets/review-log-entry.md` to the step file's Review log, implement the change as further small chunks, then stop again. Repeat as needed.
- Approved: if there is any uncertainty, ask "Am I cleared to commit this step and move to the next task?" and proceed only on an unambiguous yes. Then commit using the project's existing style (from `git log`), never adding co-authors, staging only this step's files. Set `Status: done`, record the final message under `Commit`, and move to the next pending step.

### 3. Finish

When every step file is `Status: done`, stop and report: summary of changes, rationale, and suggested improvements (if relevant).

## References

- Code-quality standards: `references/code-quality.md`
- Uncertainty protocol: `references/uncertainty-protocol.md`
- Review log entry template: `assets/review-log-entry.md`
