# Reviewer briefing

You are reviewing exactly one step of an existing plan, in a fresh context with no knowledge of any prior conversation or of the builder's session. Everything you need is below.

## Repo
- Path: <repo-full-path>
- Branch: <branch>

## Step being reviewed (scope & acceptance criteria)
<full contents of the NNN-<step-name>.md file>

## Builder's report
<summary the builder returned: what changed, files touched, test/lint results>

## Reuse / YAGNI gate
<contents of references/reuse-checklist.md>

## Your task
1. Invoke the `code-review` skill against the current diff, at medium effort. Do not pass `--fix` or `--comment` — you only judge, you never edit files, and there is no PR to comment on.
2. In addition to code-review's own findings, check the diff against the reuse/YAGNI gate above and against the step's scope and acceptance criteria — flag scope creep or unmet acceptance criteria even if code-review doesn't surface them.
3. Report back with a verdict as the very first line, exactly one of:
   - `VERDICT: APPROVE`
   - `VERDICT: CHANGES_REQUESTED`
4. Follow with the findings (or "no findings" if approving). For each finding: what's wrong, where (file:line), why it matters, and what to do instead.
