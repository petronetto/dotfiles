---
name: build-auto
description: Autonomously drive an existing plan to completion using isolated builder and reviewer sub-agents per step, build, review via `review`, fix, commit, repeat, with no human checkpoint between steps. Trigger on "build-auto", "autopilot", "ship the plan", "run the plan".
argument-hint: "[task-name]"
---

# Build Auto

Drive a plan from `plan` to completion. Per step: a fresh-context **builder** sub-agent implements it, a fresh-context **reviewer** sub-agent audits the diff via `review`. Loop builder to reviewer until approved, then commit and move on. Unlike `build`, there is no human gate mid-run; the reviewer is the gate. State lives on disk (plan files, git history), so a run is always auditable and resumable.

## Hard rules

- Work steps in dependency order. Steps with no dependency between them and disjoint files may be built in parallel (one builder per step), each still reviewed and committed on its own.
- Builder and reviewer each run in their own fresh sub-agent—never inline in the orchestrator's context.
- Keep every context clean: the orchestrator carries only plan state and the current step's verdict/findings, not full diffs or build logs. Sub-agent briefings carry only what that agent needs—no orchestrator history, no other steps' detail.
- Every briefing includes: the plan's `PRD.md`, the step file, `references/code-quality.md`, `references/reuse-checklist.md`.
- Reviewer only judges—it runs `review`, no `--fix`/`--comment`, never edits files.
- Each step's new or changed behavior has a test that failed before and passes after; the reviewer confirms this. Apply the `test` skill's discipline.
- Max **3** build-to-review cycles per step. Still unresolved after 3 -> `Status: blocked`, log why, move on. Don't stop to ask the human mid-run.
- Commit only after the reviewer `APPROVE`. One commit per step, only that step's files, in the project's own style. Never reference the plan, step, or chunk in the commit message or in code comments (plans are not committed); describe the actual change.
- Never expand scope beyond the step file. Preserve existing behavior unless the step requires otherwise.

## Procedure

### 1. Locate the plan
Plans live in `.plans/<branch>/<task-name>/`. Find the most recent `<task-name>` with `Status: pending` (or `blocked`, when resuming) steps. Ask which to run if ambiguous—the one point worth pausing for, since it sets the scope of an otherwise unattended run.

### 2. Loop over steps
Repeat until no `pending` steps remain (independent steps may run through this loop in parallel):

**a. Announce** — State the step and goal, set `Status: in-progress`.

**b. Build** — Spawn a builder sub-agent briefed with `assets/builder-brief.md` filled in (step file, code-quality, reuse gate, repo/branch, and prior findings on retries). It implements the chunks, adds or updates tests per the step's Verification, runs the project's tests and linters, doesn't commit, and reports back a summary—or reports itself blocked with a reason.

**c. Review** — Spawn a reviewer sub-agent briefed with `assets/reviewer-brief.md` filled in (step file, builder's report, reuse gate). It runs `review` at medium effort against the diff, also checks scope and acceptance criteria plus the reuse gate, and confirms the new behavior is covered by a test, returning a first-line verdict: `VERDICT: APPROVE` or `VERDICT: CHANGES_REQUESTED` plus findings.

**d. Evaluate** — Log the verdict via `assets/review-log-entry.md`, then:
- `APPROVE` → go to (e).
- `CHANGES_REQUESTED` or builder blocked → under 3 cycles: spawn a new builder with the findings, back to (c). At cycle 3: `Status: blocked`, log why, move to the next step.

**e. Commit** — Stage only this step's files, commit per project style, no scope/step wording, no co-author trailer. `Status: done`, record the commit message, move on.

### 3. Finish
Report steps completed (with commits), steps `blocked` (with why), and suggested follow-ups. Never treat `blocked` as done.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "Three cycles is enough, skip the rest." | `blocked` is not `done`. A blocked step is reported as unresolved, never committed as complete. |
| "The reviewer can also fix it." | The reviewer only judges. Mixing judgment and fixing loses the independent audit. |
| "Let me commit before review passes." | A pre-approval commit breaks the clean per-step rollback and bypasses the gate. |
| "I'll fold the other step in too." | One commit per step, only its files, is what makes each step independently reversible. |
| "It's faster to inline the sub-agent." | Fresh contexts are the point; inline reuse leaks one step's noise into another. |

## Red flags

- Committing a step whose reviewer did not `APPROVE`.
- A step advancing with failing or missing tests.
- Orchestrator context carrying full diffs or build logs instead of just verdicts/findings.
- A briefing missing `PRD.md`, the step file, or the reuse gate.
- `blocked` reported as `done`, or scope expanding past the step file.

## Verification

Before a step counts as done:
- [ ] The reviewer returned `VERDICT: APPROVE` within 3 cycles (or the step is `blocked`).
- [ ] New/changed behavior has a test that failed before and passes after.
- [ ] The commit touched only this step's files and carried no plan/step wording.
- [ ] No `blocked` step was treated as complete.

## References

- Code-quality standards: `references/code-quality.md`
- Reuse/YAGNI gate (builder and reviewer both apply it): `references/reuse-checklist.md`
- Review log entry template: `assets/review-log-entry.md`
- Builder briefing template: `assets/builder-brief.md`
- Reviewer briefing template: `assets/reviewer-brief.md`
- The gate itself: `review` skill · test discipline: `test` skill · human-gated variant: `build` skill
