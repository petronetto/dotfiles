---
name: plan
description: Decompose a PRD into small, ordered, reviewable step files before coding. Trigger on "plan", "break down", "decompose the spec". Reads the PRD (`PRD.md` from `spec`) and writes per-step files only, never code.
argument-hint: "[task-name]"
---

# Plan

Turn a PRD into tiny, reviewable step files. Plans only; implementation is separate (`build`). If there is no PRD yet, run `spec` first. State lives on disk; every run re-derives context from git and the filesystem.

## Hard rules

- Never write or edit code—output is Markdown only.
- One responsibility per step; each step leaves the codebase working.
- Read the PRD for problem, approach, and key decisions; link step files back to it instead of restating.
- Prefer a reframing that deletes complexity over one that rearranges it (see `~/.agents/references/code-quality.md`).
- Never delete an existing plan. Ask before resuming or starting a new one.

## Procedure

### 1. Establish context
- Get repo path, branch, and commit style from git.
- Use sub-agents to explore the codebase enough to plan responsibly.
- Prefer quality and simplicity over development cost.

### 2. Locate or create the plan directory
```
<project-full-path>/.plans/<branch>/<task-name>/
```
`<task-name>` is a short git-safe slug. Read `PRD.md` there for the spec. If it is missing, stop and ask the user to run `spec` first (or offer to produce a minimal PRD inline); don't plan onto an undefined spec. If the directory holds unfinished steps, ask whether to resume or start a new plan. "Start a new plan" means picking a different `<task-name>` slug (and running `spec` for it if no PRD exists yet) — never overwrite an existing plan's step files, per the hard rule against deleting one.

### 3. Decompose into ordered steps
Break the PRD into tiny, independently-reviewable steps. Each has one responsibility, can be reverted alone, and leaves the codebase working. Keep independent steps independent and record real dependencies in `Depends`; steps with no dependency between them can be built in parallel. Every step must deliver a working change on its own, no scaffolding-only chunks (e.g. enums or types nothing consumes yet).

### 4. Write one file per step
```
<project-full-path>/.plans/<branch>/<task-name>/NNN-<step-name>.md
```
Fill the template at `assets/step-file.md` for each step (NNN = zero-padded ordinal from 000). Update the PRD's "Steps" index in `PRD.md` to match.

### 5. Present and stop
Summarize the plan and list the files created. Do not implement. Hand off to `build` only after approval.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "The steps are obvious." | Write them anyway. Explicit steps surface hidden dependencies and forgotten edge cases. |
| "I can hold it all in my head." | Context windows are finite. Step files survive session boundaries and compaction. |
| "It'll get planned while implementing." | Planning without decomposition is just typing with no checkpoints. |
| "One big step is fine." | A large step hides a bug and makes a rollback painful. Small, working steps are free. |

## Red flags

- Implementing without written, reviewed step files.
- A step that says "implement the feature" with no acceptance criteria or verification.
- No `Depends` recorded, or steps that don't each leave the codebase working.

## Verification

Before handing off to `build`, confirm:
- [ ] The PRD (`PRD.md`) is approved.
- [ ] Every step file has a goal, in/out-of-scope, and acceptance criteria.
- [ ] Every step has a verification step (test, build, or manual check).
- [ ] Each step's verification confirms the codebase still builds/runs after that step lands alone, not just that its own new behavior works.
- [ ] Step verification criteria account for the Definition of Done (`~/.agents/references/definition-of-done.md`), not just each step's own acceptance criteria.
- [ ] Dependencies are recorded; independent steps are marked as parallelizable.
- [ ] No step is scaffolding-only.
- [ ] The user reviewed and approved the plan.

## References

- Definition of Done: `~/.agents/references/definition-of-done.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- Step file template: `assets/step-file.md`
- PRD template (owned by `spec`, updated here): `assets/prd-file.md`
