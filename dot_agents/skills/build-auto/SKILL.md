---
name: build-auto
description: Autonomously drive an existing plan to completion using isolated builder and reviewer sub-agents per step, build, review via `review`, fix, commit, repeat, with no human checkpoint between steps. Trigger on "build-auto", "autopilot", "ship the plan", "run the plan".
---

# Build Auto

Drive a plan from `plan` to completion. Per step: a fresh-context **builder** sub-agent implements it, a fresh-context **reviewer** sub-agent audits the diff via `review`. Loop builder to reviewer until approved, then commit and move on. Unlike `build`, there is no human gate mid-run; the reviewer is the gate. State lives on disk (plan files, git history), so a run is always auditable and resumable.

## Hard rules

- Work steps in dependency order. Steps with no dependency between them and disjoint files may be built in parallel (one builder per step), each still reviewed and committed on its own.
- Parallel builders each work in their own git worktree (`scripts/worktree.sh create`), never the shared working tree — concurrent uncommitted edits, staging, and commits in one working tree collide and corrupt each other's diffs. A step built alone (no other step running concurrently) may use the main working tree directly.
- A step whose `Depends` step is `Status: blocked` is not built. Mark it `Status: blocked` too (reason: "blocked by <dependency step>"), log it, and move to the next step.
- Builder and reviewer each run in their own fresh sub-agent—never inline in the orchestrator's context.
- Keep every context clean: the orchestrator carries only plan state and the current step's verdict/findings, not full diffs or build logs. Sub-agent briefings carry only what that agent needs—no orchestrator history, no other steps' detail.
- Every briefing includes: the plan's `PRD.md`, the step file, `~/.agents/references/code-quality.md`, `~/.agents/references/reuse-checklist.md`, `~/.agents/references/definition-of-done.md`. The reviewer's briefing additionally includes the project standards gathered once in step 1.
- Reviewer only judges—it runs `review`, no `--fix`/`--comment`, never edits files.
- Each step's new or changed behavior has a test that failed before and passes after; the reviewer confirms this. Apply the `test` skill's discipline.
- Max **3** build-to-review cycles per step. Still unresolved after 3 -> `Status: blocked`, log why, move on. Don't stop to ask the human mid-run.
- Commit only after the reviewer `APPROVE`. One commit per step, only that step's files, in the project's own style. Never reference the plan, step, or chunk in the commit message or in code comments; describe the actual change.
- Never expand scope beyond the step file. Preserve existing behavior unless the step requires otherwise.

## Gotchas

- Two builders sharing the main working tree corrupts both diffs — concurrent uncommitted edits, staging, and commits collide. Parallel steps must each get their own git worktree (`scripts/worktree.sh create`); a step running alone may use the shared tree directly.
- The reviewer only judges — it never fixes, comments, or edits files. Handing it fix authority collapses the independent audit the whole loop depends on.
- Commit messages and code comments must never reference the plan, step, or chunk.

## Available scripts

- **`scripts/worktree.sh`** — Creates an isolated worktree for a parallel step (`create`) and merges + removes it once the step is approved (`finish`).

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
Run `plan-cli list` to enumerate the task directories; each printed line is that task's `<location>`. For each candidate, run `plan-cli read <location> FLOW.md` to get its step file names, then `plan-cli read` each step file, and find the most recent `<location>` with `Status: pending`, `in-progress` (an earlier run was interrupted mid-step), or `blocked` (unresolved after 3 cycles) steps. Ask which to run if ambiguous: the one point worth pausing for, since it sets the scope of an otherwise unattended run. For an `in-progress` step, inspect the working tree for partial changes before briefing a builder — treat them as the builder's starting point, not as contamination to discard. Also gather the project standards (PRD's Commands section, plus any linter/CI config or conventions found via the `test` skill's "discover the stack" step) once here, and reuse them in every reviewer briefing for this run.

### 2. Loop over steps
Repeat until no `pending` steps remain (independent steps may run through this loop in parallel):

**a. Announce** — State the step and goal. If any `Depends` step is `Status: blocked`, run `plan-cli set-status <location> --step <step-file> --status blocked --reason "blocked by <dependency step>"`, log it (`plan-cli append <location> <step-file>`) in the `assets/review-log-entry.md` format, and skip to the next step. Otherwise run `plan-cli set-status <location> --step <step-file> --status in-progress`.

**b. Build** — Spawn a builder sub-agent briefed with `assets/builder-brief.md` filled in (step file, code-quality, reuse gate, repo/branch, and prior findings on retries). If this step is running in parallel with another, first run `scripts/worktree.sh create <plan-branch> <step-slug>` to create an isolated worktree for it, and brief the builder to work there instead of the shared tree. It implements the chunks, adds or updates tests per the step's Verification, runs the project's tests and linters, doesn't commit, and reports back a summary—or reports itself blocked with a reason.

**c. Review** — Spawn a reviewer sub-agent briefed with `assets/reviewer-brief.md` filled in (step file, builder's report, reuse gate). It runs `review` at medium effort against the diff, also checks scope and acceptance criteria plus the reuse gate, and confirms the new behavior is covered by a test, returning a first-line verdict: `VERDICT: APPROVE` or `VERDICT: CHANGES_REQUESTED` plus findings.

**d. Evaluate** — Log the verdict (`plan-cli append <location> <step-file>`) in the `assets/review-log-entry.md` format, then:
- `APPROVE` → go to (e).
- `CHANGES_REQUESTED` or builder blocked → under 3 cycles: spawn a new builder with the findings, back to (c). At cycle 3: run `plan-cli set-status <location> --step <step-file> --status blocked --reason <one-line reason>` (the header `Blocked` field fills in addition to the review log entry), move to the next step.

**e. Commit** — Stage only this step's files, commit per project style, no scope/step wording, no co-author trailer. If built in an isolated worktree, run `scripts/worktree.sh finish <worktree-path> <plan-branch>` to merge the step branch into the plan branch and remove the worktree. Run `plan-cli set-status <location> --step <step-file> --status done`, then record the commit message under the step file's `Commit` section: `plan-cli read` the file, fill the section, write it back via `plan-cli write`. Move on.

### 3. Finish
**Audit the delivered work against the PRD** — Spawn a fresh-context auditor sub-agent briefed with the PRD and the step files' acceptance criteria: it checks the delivered code against the PRD's goals and scenarios (not the step logs; completion claims are not evidence) and classifies every gap as `missing`, `partial`, `contradicts`, or `unrequested` (surfaced in the report, never deleted). Work each gap through the affected step's own loop — builder, reviewer, commit, same 3-cycle cap; a gap unresolved after 3 cycles marks that step `Status: blocked`, never done. A pure refactor (`No behavior change`) audits against preserved behavior instead.

Then report steps completed (with commits), steps `blocked` (with why), gaps left by the audit, and suggested follow-ups. Never treat `blocked` as done. If the PRD's Roadmap field names an entry in the `roadmap` task's `ROADMAP.md` and every step of that PRD's plan is `done`, run `plan-cli set-status <roadmap-location> --entry <id> --status done` with the `roadmap` task's `<location>`, its entry from step 1's enumeration, before reporting.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "Three cycles is enough, skip the rest." | `blocked` is not `done`. A blocked step is reported as unresolved, never committed as complete. |
| "The reviewer can also fix it." | The reviewer only judges. Mixing judgment and fixing loses the independent audit. |
| "Let me commit before review passes." | A pre-approval commit breaks the clean per-step rollback and bypasses the gate. |
| "I'll fold the other step in too." | One commit per step, only its files, is what makes each step independently reversible. |
| "It's faster to inline the sub-agent." | Fresh contexts are the point; inline reuse leaks one step's noise into another. |
| "The steps all passed review, so the PRD is satisfied." | Per-step review proves each step, not the whole contract; the audit closes the loop between spec and implementation. |

## Red flags

- Committing a step whose reviewer did not `APPROVE`.
- A step advancing with failing or missing tests.
- Orchestrator context carrying full diffs or build logs instead of just verdicts/findings.
- A briefing missing `PRD.md`, the step file, or the reuse gate.
- `blocked` reported as `done`, or scope expanding past the step file.
- An audit gap silently dropped instead of looped or reported as `blocked`.

## Verification

Before a step counts as done:
- [ ] The reviewer returned `VERDICT: APPROVE` within 3 cycles (or the step is `blocked`, with its header `Blocked` field filled).
- [ ] New/changed behavior has a test that failed before and passes after.
- [ ] The commit touched only this step's files and carried no plan/step wording.
- [ ] No `blocked` step was treated as complete, and no step was built while its `Depends` step was `blocked`.
- [ ] Parallel steps were each built in their own worktree, not the shared working tree.
- [ ] The Definition of Done (`~/.agents/references/definition-of-done.md`) is satisfied; the reviewer confirmed it, not just the step's acceptance criteria.

Before the plan counts as finished:
- [ ] The acceptance audit ran against the PRD's goals and scenarios; every gap was either resolved through the loop or reported as `blocked`, never silently dropped.

## References

- Definition of Done: `~/.agents/references/definition-of-done.md`
- Code-quality standards: `~/.agents/references/code-quality.md`
- Reuse/YAGNI gate (builder and reviewer both apply it): `~/.agents/references/reuse-checklist.md`
- Review log entry template: `assets/review-log-entry.md`
- Builder briefing template: `assets/builder-brief.md`
- Reviewer briefing template: `assets/reviewer-brief.md`
- Worktree lifecycle script: `scripts/worktree.sh`
- The gate itself: `review` skill · test discipline: `test` skill · human-gated variant: `build` skill
- Plan CLI: `~/.agents/plan-adapters/plan` (a bare call prints usage; backend settings: `~/.agents/plans.config.md`)
