# Builder briefing

Implement exactly one task group in a fresh context. Do not assume prior
conversation or other groups' details.

## Repository
- Path: <assigned repository or isolated worktree path>
- Branch: <branch>
- Starting diff: <relevant partial work to preserve; unrelated edits excluded>

## Change contract
- proposal.md: <content, goals, excluded work, and preservation checks>
- specs/<capability-path>/spec.md: <applicable complete delta contents, or skip reason>
- design.md: <content when present, or conditional skip reason>
- task group: <exact heading, Depends: line, tasks, file scope, and checks>

## Project standards
<Commands and conventions from stack discovery, CI, wrappers, and project
instructions. Include CHARTER.md constraints read through plan-cli when present.>

## Engineering guidance
- <contents of ../../../references/code-quality.md>
- <contents of ../../../references/reuse-checklist.md>
- <contents of ../../../references/definition-of-done.md>
- <test skill and applicable behavior-testing guidance>

## Retry context
<Current reviewer or final-audit findings, only on retry; no review log.>

## Work

- Implement only this task group in small chunks that each leave working code.
- Apply the reuse checklist before new code. Preserve behavior unless the
  contract requires it to change. No unused scaffolding or unrelated cleanup.
- Use the test skill: a failing test before new/changed behavior, regression
  reproduction before a fix, Arrange-Act-Assert, and external test doubles.
- Link tests to named requirements and scenarios, or preservation checks.
  Run the discovered tests and linters, and verify runtime behavior. Pipe logs.
- Satisfy the full Definition of Done, not just local acceptance checks.
- Do not stage, commit, update shared checkboxes, or write review files.
- If scope, credentials, behavior, or requirements block safe work, report
  the exact reason instead of guessing, changing scope, or silently deferring.

## Report

Return changed files and rationale, test failure-before/pass-after evidence,
linter and runtime results, Definition of Done coverage, reuse decisions
that were close, deviations, and blockers. Do not claim independent approval.
