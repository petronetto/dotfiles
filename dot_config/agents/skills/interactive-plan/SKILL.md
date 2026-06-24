---
name: interactive-plan
description: Plan a feature or fix as small, individually-reviewable steps, then implement them one chunk at a time, stopping after every step for human review and explicit approval before committing and moving on. Use for interactive plan, step-by-step implementation, plan-and-build, or review-gated implementation loops.
argument-hint: "<feature or fix description>"
---

# Interactive Plan

Use this skill to turn a feature or fix into a sequence of tiny, reviewable steps and then implement them under a strict human-in-the-loop review gate.

Two phases, never blurred together:

1. **Plan phase** — write the plan to disk as one file per step. No code changes.
2. **Implementation loop** — implement one step at a time in small chunks, stop, wait for review, then commit and advance only with explicit approval.

The planning and the implementation must both uphold the standards of the `code-quality-review` skill: be ambitious about structural simplicity, prefer deleting complexity over rearranging it, keep files small and cohesive, avoid spaghetti branching, and program to clear boundaries. Plan for the simplest design that could possibly work, not the first one that comes to mind.

## Hard Rules (Non-Negotiable)

- **Never write code during the plan phase.** Planning produces only Markdown files.
- **Implement exactly one step at a time.** Never start the next step before the current one is approved.
- **Break each step into small chunks.** Each chunk must be small enough to review comfortably (rule of thumb: a focused, self-contained diff a human can read in a couple of minutes). Prefer more, smaller chunks over one large diff.
- **Stop after every step and wait.** After finishing a step's chunks, stop and explicitly hand control back to the user for review. Do not continue on your own.
- **Never commit unless the user explicitly approves.** Approval is per-step and must be unambiguous.
- **Never mark a task done or advance under any uncertainty.** If there is *any* doubt about whether the step is complete, correct, or approved, do not proceed — ask the user, in plain terms, whether you are allowed to move to the next task. When in doubt, stop and ask.
- **Preserve existing behavior** unless the step explicitly requires changing it.

## Phase 1 — Build the Plan

### 1. Establish context

Before writing anything, gather the facts you need and confirm them:

- Run `git rev-parse --show-toplevel` to find the repo root. Keep its absolute path as `<project-full-path>` (where the code lives) and derive the folder id `<project>` from its basename.
- Run `git rev-parse --abbrev-ref HEAD` to get `<branch>`. Slugify it (lowercase, replace `/` and other unsafe characters with `-`, collapse repeats).
- Get the current date as `YYYYMMDD` (use `date +%Y%m%d`).
- Inspect recent commits with `git log --oneline -20` to learn the project's commit style (prefix conventions, Conventional Commits, tense, scope, etc.). You will reuse this style later.
- Understand the codebase well enough to plan responsibly. If the request is ambiguous, ask one concise clarifying question at a time. Never make assumptions.
- When making technical decisions, do not give much weight to development cost. Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.

### 2. Choose the plan directory

Each plan gets its own directory, named after the overall task being planned:

```
$HOME/.agents/plans/<project>/<branch>/YYYYMMDD/<task-name>/
```

where `<task-name>` is a short git-safe slug for the whole feature/fix. Create the directory if it does not exist. Because every plan lives in its own `<task-name>` folder, distinct plans never collide — even on the same day. If a `<task-name>` directory already exists with unfinished step files, do not delete anything: ask the user whether to resume its implementation or start a new plan (under a different `<task-name>`). Never delete a completed plan; it is a durable record.

### 3. Decompose into ordered steps

Break the work into the smallest sequence of independently-reviewable, behavior-preserving (where possible) steps. A good step:

- has a single clear responsibility,
- can be reviewed and reverted on its own,
- leaves the codebase in a working state when finished,
- moves toward the simplest viable end design.

Be ambitious about simplification while decomposing: if a "code judo" reframing lets whole steps disappear, prefer that plan.

### 4. Write one file per step

Each step is its own file inside the plan's `<task-name>` directory:

```
$HOME/.agents/plans/<project>/<branch>/YYYYMMDD/<task-name>/NNN-<step-name>.md
```

where `NNN` is a zero-padded ordinal starting at `000` (`000`, `001`, `002`, …) and `<step-name>` is a short git-safe slug for that individual step.

Use this template for every step file:

```markdown
# NNN — <Task Title>

| Field    | Value                              |
| -------- | ---------------------------------- |
| Status   | pending                            |
| Date     | YYYY-MM-DD                         |
| Project  | <project-full-path>                |
| Branch   | <branch>                           |
| Depends  | <previous step file(s), or none>   |

## Goal
One or two sentences describing exactly what this step delivers and why.

## Scope
- In scope: ...
- Out of scope: ... (explicitly list what this step must NOT touch)

## Files & boundaries
Files/modules expected to change, and the boundaries/interfaces involved.

## Implementation chunks
Ordered list of the small chunks this step will be split into. Each chunk is a
tiny, self-contained diff the user can review on its own.
1. Chunk A — ...
2. Chunk B — ...

## Verification
How this step is proven correct: tests to add/run, linters, manual checks.
Test behavior, not implementation. Use AAA and mock external dependencies.

## Acceptance criteria
Concrete, checkable conditions that must all hold for the step to be "done".

## Review log
(Appended during the implementation loop — see below.)

## Commit
(Filled in only after approval, with the final commit message used.)
```

### 5. Present the plan and wait

After writing all step files, give the user a short prose summary of the plan and the list of files created. **Stop and wait** for the user to confirm the plan before any implementation begins. Do not start coding on your own.

## Phase 2 — Implementation Loop

Repeat for each step in order, starting from the lowest `NNN` with `Status: pending`:

### 1. Announce the step
State which step file you are about to implement and its goal. Set its `Status` to `in-progress` in the file.

### 2. Implement in small chunks
Implement the step strictly as small chunks, in order. Keep each chunk focused and easy to review. Follow the `code-quality-review` standards while coding: no spaghetti branching, no needless abstractions, small cohesive files, explicit boundaries. Add/update tests as described in the step's Verification section and run linters/tests where available, piping long output.

### 3. Stop for review
When the step's chunks are complete, **stop and hand control to the user**. Clearly say the step is ready for review and that you are waiting. Do not commit. Do not start the next step.

### 4. Handle the user's response

- **If the user requests modifications:** append a dated entry to the step file's `Review log` describing the requested change, implement the change as further small chunks, then **stop again** and wait. Repeat as many times as needed.
- **If the user approves:**
  1. If there is *any* uncertainty about completeness, correctness, or that approval was truly given, **do not advance** — ask the user explicitly: "Am I cleared to commit this step and move to the next task?" Proceed only on an unambiguous yes.
  2. Create a commit using the project's existing commit style (discovered from `git log`). Never add co-authors. Stage only the files relevant to this step.
  3. In the step file, set `Status: done` and record the final commit message under `Commit`.
  4. Move to the next pending step and repeat the loop.

### 5. Finish
When every step file is `Status: done`, stop and report completion. Summarize what was built, the commits created, and any follow-up suggestions.

## Review log entry format

When appending to a step's `Review log`, use:

```markdown
### YYYY-MM-DD HH:MM — Revision N
- Requested: <what the user asked to change>
- Done: <what you changed, which chunks>
```

## Uncertainty Protocol (read twice)

The most important rule of this skill: **the agent must never mark a task as done or move to the next task while any uncertainty exists.** Uncertainty includes (but is not limited to): unclear approval, failing or missing tests, unresolved review comments, ambiguous requirements, or unexpected diffs. In every such case, stop and ask the user, in plain language, whether you are allowed to proceed. Silence or assumption is never approval.

## End-of-task output

At the end of the task, provide:
- ✅ Summary of changes
- ✅ Rationale
- ✅ Suggested improvements (if relevant)
