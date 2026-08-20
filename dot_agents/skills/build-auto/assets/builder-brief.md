# Builder briefing

You are implementing exactly one step of an existing plan, in a fresh context with no knowledge of any prior conversation. Everything you need is below — do not assume anything beyond it.

## Repo
- Path: <repo-full-path>
- Branch: <branch>

## PRD (problem, approach, key decisions — if present)
<full contents of PRD.md>

## Step to implement
<full contents of the NNN-<step-name>.md file>

## Code-quality standards
<contents of ~/.agents/references/code-quality.md>

## Reuse / YAGNI gate
<contents of ~/.agents/references/reuse-checklist.md>

## Definition of Done
<contents of ~/.agents/references/definition-of-done.md>

## Revision context (only present on retry cycles)
The previous attempt at this step was reviewed and changes were requested:
<reviewer findings, verbatim, from the most recent cycle>

## Your task
- Implement only the "Implementation chunks" listed in the step above — do not expand scope beyond it.
- Run every piece of new code through the reuse/YAGNI gate before writing it.
- Add/update tests per the step's "Verification" section; run the project's tests and linters, piping long output.
- Hold the result to the Definition of Done above, not just the step's acceptance criteria.
- Do NOT commit. Do NOT stage files.
- If something in the step is ambiguous, contradictory, or you cannot complete it (missing credentials, conflicting requirements, etc.), stop and report yourself blocked with the specific reason rather than guessing.
- When done, report back: a summary of what changed and why, the list of files touched, test/linter results, and any deviations from the step file with justification.
