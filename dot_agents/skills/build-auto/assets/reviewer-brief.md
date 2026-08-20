# Reviewer briefing

You are reviewing exactly one step of an existing plan, in a fresh context with no knowledge of any prior conversation or of the builder's session. Everything you need is below.

## Repo
- Path: <repo-full-path>
- Branch: <branch>

## PRD (problem, approach, key decisions — if present)
<full contents of PRD.md>

## Step being reviewed (scope & acceptance criteria)
<full contents of the NNN-<step-name>.md file>

## Builder's report
<summary the builder returned: what changed, files touched, test/lint results>

## Code-quality standards
<contents of ~/.agents/references/code-quality.md>

## Reuse / YAGNI gate
<contents of ~/.agents/references/reuse-checklist.md>

## Project standards
<the plan's PRD.md "Commands" section (build/test/lint/dev commands), plus any linter/CI config or conventions the orchestrator found via the `test` skill's "discover the stack" step when the plan was located — gathered once per run and reused across every step's briefing, not invented per step.>

## Your task
1. Invoke the `review` skill against the current diff, at medium effort. Do not pass `--fix` or `--comment` — you only judge, you never edit files, and there is no PR to comment on.
2. In addition to review's own findings, check the diff against the reuse/YAGNI gate above and against the step's scope and acceptance criteria — flag scope creep or unmet acceptance criteria even if review doesn't surface them. Use the PRD's non-goals and key decisions to judge borderline cases, not the step file alone.
3. Report back with a verdict as the very first line, exactly one of:
   - `VERDICT: APPROVE`
   - `VERDICT: CHANGES_REQUESTED`
4. Follow with the findings (or "no findings" if approving). For each finding: what's wrong, where (file:line), why it matters, and what to do instead.
