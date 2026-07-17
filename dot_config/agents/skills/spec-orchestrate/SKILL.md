---
name: spec-orchestrate
description: Autonomously drive an existing spec-build plan to completion using isolated builder and reviewer sub-agents per step — build, review via /code-review, fix, commit, repeat — with no human checkpoint between steps. Trigger on "orchestrate", "autopilot", "ship the plan", "run the plan".
argument-hint: "[task-name]"
---

# Spec Orchestrate

Drive a plan from `spec-plan` to completion. Per step: a fresh-context **builder** sub-agent implements it, a fresh-context **reviewer** sub-agent audits the diff via `code-review`. Loop builder ↔ reviewer until approved, then commit and move on. Unlike `spec-build`, no human gate mid-run — the reviewer is the gate. State lives on disk (plan files, git history), so a run is always auditable and resumable.

## Hard rules

- One step at a time, in order.
- Builder and reviewer each run in their own fresh sub-agent — never inline in the orchestrator's context.
- Keep every context clean: the orchestrator carries only plan state and the current step's verdict/findings, not full diffs or build logs. Sub-agent briefings carry only what that agent needs — no orchestrator history, no other steps' detail.
- Every briefing includes: the plan's `summary.md`, the step file, `references/code-quality.md`, `references/reuse-checklist.md`.
- Reviewer only judges — runs `code-review`, no `--fix`/`--comment`, never edits files.
- Max **3** build↔review cycles per step. Still unresolved after 3 → `Status: blocked`, log why, move on. Don't stop to ask the human mid-run.
- Commit only after reviewer `APPROVE`. One commit per step, only that step's files, project's own style. Never write "step N" / "phase N" / "chunk N" in the message — describe the actual change.
- Never expand scope beyond the step file. Preserve existing behavior unless the step requires otherwise.

## Procedure

### 1. Locate the plan

Plans live in `.plans/<branch>/<task-name>/`. Find the most recent `<task-name>` with `Status: pending` (or `blocked`, if resuming) steps. Ask which to run if ambiguous — the one point worth pausing for, since it sets the scope of an otherwise unattended run.

### 2. Loop over steps

Repeat until no `pending` steps remain:

**a. Announce** — state the step and goal, set `Status: in-progress`.

**b. Build** — spawn a builder sub-agent briefed with `assets/builder-brief.md` filled in (step file, code-quality, reuse gate, repo/branch, and prior findings on retries). It implements the chunks, runs tests/linters, doesn't commit, and reports back a summary — or reports itself blocked with a reason.

**c. Review** — spawn a reviewer sub-agent briefed with `assets/reviewer-brief.md` filled in (step file, builder's report, reuse gate). It runs `code-review` at medium effort against the diff, also checks scope/acceptance criteria and the reuse gate, and returns a first-line verdict: `VERDICT: APPROVE` or `VERDICT: CHANGES_REQUESTED` plus findings.

**d. Evaluate** — log the verdict via `assets/review-log-entry.md`, then:
- `APPROVE` → go to (e).
- `CHANGES_REQUESTED` or builder blocked → under 3 cycles: spawn a new builder with the findings, back to (c). At cycle 3: `Status: blocked`, log why, move to next step.

**e. Commit** — stage only this step's files, commit per project style, no scope/step wording, no co-author trailer. `Status: done`, record the commit message, move on.

### 3. Finish

Report steps completed (with commits), steps `blocked` (with why), and suggested follow-ups. Never treat `blocked` as done.

## References

- Code-quality standards: `references/code-quality.md`
- Reuse/YAGNI gate (builder and reviewer both apply it): `references/reuse-checklist.md`
- Review log entry template: `assets/review-log-entry.md`
- Builder briefing template: `assets/builder-brief.md`
- Reviewer briefing template: `assets/reviewer-brief.md`
