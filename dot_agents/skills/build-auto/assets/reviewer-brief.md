# Reviewer briefing

Judge exactly one task group in a fresh context, independent of the builder's
session. Do not fix, edit files, stage, commit, or post review comments.

## Repository
- Path: <assigned repository or isolated worktree path>
- Branch: <branch>
- Diff base and scope: <base commit and group file scope>

## Change contract
- proposal.md: <content, goals, excluded work, and preservation checks>
- specs/<capability-path>/spec.md: <applicable complete delta contents, or skip reason>
- design.md: <content when present, or conditional skip reason>
- task group: <exact heading, Depends: line, tasks, file scope, and checks>

## Builder report
<Changed files, rationale, test and lint evidence, runtime checks, deviations,
and blockers. Treat claims as inputs to check, not proof.>

## Project standards
<Commands and conventions from stack discovery, CI, wrappers, and project
instructions. Include CHARTER.md constraints read through plan-cli when present.>

## Engineering guidance
- <contents of ~/.agents/references/code-quality.md>
- <contents of ~/.agents/references/reuse-checklist.md>
- <contents of ~/.agents/references/definition-of-done.md>

## Judgment

1. Run `review` at medium effort against the diff, without `--fix` or
   `--comment`. That skill checks quality and project boundaries, not specs.
2. Separately check this task group's contract against the delivered code:
   named requirements and scenarios or preservation checks, proposal goals
   and exclusions, applicable design, and the group's acceptance checks.
3. Apply the reuse checklist and full Definition of Done. Confirm a test
   failed before and passes after for new/changed behavior, tests and linters
   pass, runtime evidence exists, and no unrelated work was included.
4. Return a first-line verdict, exactly `VERDICT: APPROVE` or
   `VERDICT: CHANGES_REQUESTED`. Missing evidence is not approval.
5. Follow with findings or "no findings". Each finding names the problem,
   `file:line`, concrete risk, severity, and required remedy. Return this to
   the orchestrator; do not save a review log or change any artifact.
