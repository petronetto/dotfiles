---
name: plan
description: Decompose a PRD into small, ordered, reviewable step files before coding. Trigger on "plan", "break down", "decompose the spec". Reads the PRD (`PRD.md` from `spec`) and writes per-step files only, never code.
---

# Plan

Turn a PRD into tiny, reviewable step files. Plans only; implementation is separate (`build`). If there is no PRD yet, run `spec` first. State lives on disk; every run re-derives context from git and the filesystem.

## Hard rules

- Never write or edit code—output is Markdown only.
- One responsibility per step; each step leaves the codebase working.
- Read the PRD for problem, approach, and key decisions; read `CONTEXT.md` for the provenance behind those decisions, and link step files back to them instead of restating. Treat any `ADR-NNN-*.md` as the authoritative record for the decision it covers.
- Prefer a reframing that deletes complexity over one that rearranges it (see `~/.agents/references/code-quality.md`).
- Never delete an existing plan. Ask before resuming or starting a new one.
- Reviewability is a hard requirement: follow the Writing rules below, and split any step that cannot stay within them.

## Writing rules

Steps are written for the reviewer, not for the planner:

- Verb first, one action per chunk row, files named in every row.
- Write outcomes, not design summaries: a chunk row states what must be observably true when it is done. Mechanics go in "Done when" only where they are non-obvious; rationale lives in `decisions.md`, never in the step file.
- One sentence per table cell; no inline pseudo-code unless the algorithm is itself the deliverable.
- Say it once: behavior lives in Chunks, commands in Verify, conditions in Acceptance. A fact appears in exactly one section.
- At most ~30 content lines per step file (Review log and Commit excluded). Split the step instead of growing the file.

## Gotchas

- "Start a new plan" means picking a different `<task-name>` slug (running `spec` for it if no PRD exists yet) — never overwriting an existing plan's step files, per the hard rule against deleting one.
- A step that only adds scaffolding (a type or enum nothing consumes yet) isn't valid — every step must deliver a working, testable change on its own.

## Plan adapter

- Read `~/.agents/plans.config.md` once per run: its `adapter:` key names the
  active plan adapter. Every plan-file operation in this skill follows the
  matching recipe in `~/.agents/plan-adapters/<adapter>/<operation>.md`
  (`init`, `read`, `write`, `append`, `list`, `set-status`); no step inlines
  a plan path. `spec` reads the same config, so both skills always agree on
  the location.

## Procedure

### 1. Establish context
- Get repo path, branch, and commit style from git.
- Use sub-agents to explore the codebase enough to plan responsibly.
- Prefer quality and simplicity over development cost.

### 2. Locate or create the plan directory
Read `~/.agents/plans.config.md` once: its `adapter:` key names the active
plan adapter. Follow `~/.agents/plan-adapters/<adapter>/init.md` with
`<task-name>` (idempotent), and call the resolved directory `<location>`
for the rest of this run. Follow `~/.agents/plan-adapters/<adapter>/read.md`
on `<location>/PRD.md` for the spec, and on `<location>/CONTEXT.md` for the
discovery findings and provenance that back its decisions. Read any
`<location>/ADR-NNN-*.md` for the cross-cutting decisions they record. If
`PRD.md` is missing, stop and ask the user to run `spec` first (or offer to
produce a minimal PRD inline); don't plan onto an undefined spec. If the
directory holds unfinished steps, ask whether to resume or start a new plan
(see Gotchas). Ask these per `~/.agents/references/question-format.md`,
appending each answer to the directory's `decisions.md`, each with an
`**Evidence:**` line back to `CONTEXT.md`.

### 3. Decompose into ordered steps
Break the PRD into tiny, independently-reviewable steps. Each has one responsibility, can be reverted alone, and leaves the codebase working. Keep independent steps independent and record real dependencies in `Depends`; steps with no dependency between them can be built in parallel. Every step must deliver a working change on its own, no scaffolding-only chunks (e.g. enums or types nothing consumes yet).

### 4. Write one file per step
```
<location>/NNN-<step-name>.md
```
Fill the template at `assets/step-file.md` for each step (NNN = zero-padded ordinal from 000), following the Writing rules.

### 5. Write the flow overview
Fill the template at `assets/flow-file.md` into `FLOW.md` in the plan directory: one row per step, generated from the step files. Keep it in sync whenever steps are added, split, or reordered. Include the flow graph only when dependencies branch; omit it for strictly linear plans.

### 6. Present and stop
Present the plan for review by showing FLOW.md's table in the reply (that table is the review surface; the step files are the detail layer), then list the files created. Do not implement. Hand off to `build` only after approval.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "The steps are obvious." | Write them anyway. Explicit steps surface hidden dependencies and forgotten edge cases. |
| "I can hold it all in my head." | Context windows are finite. Step files survive session boundaries and compaction. |
| "It'll get planned while implementing." | Planning without decomposition is just typing with no checkpoints. |
| "One big step is fine." | A large step hides a bug and makes a rollback painful. Small, working steps are free. |
| "The plan needs all that detail to be safe." | Restated facts are not detail; they are reading load. One fact in one place, and the flow table carries the overview. |

## Red flags

- Implementing without written, reviewed step files.
- A step that says "implement the feature" with no acceptance criteria or verification.
- No `Depends` recorded, or steps that don't each leave the codebase working.

## Verification

Before handing off to `build`, confirm:
- [ ] The PRD (`PRD.md`) is approved.
- [ ] Every step file has Delivers, Out of scope, a Chunks table with files and "Done when" on every row, and Acceptance criteria.
- [ ] No fact is restated across sections; each appears once (spot-check one step).
- [ ] `FLOW.md` exists with one row per step and matches the step files.
- [ ] Every step has a verification step (test, build, or manual check).
- [ ] Each step's verification confirms the codebase still builds/runs after that step lands alone, not just that its own new behavior works.
- [ ] Step verification criteria account for the Definition of Done (`~/.agents/references/definition-of-done.md`), not just each step's own acceptance criteria.
- [ ] Dependencies are recorded; independent steps are marked as parallelizable.
- [ ] No step is scaffolding-only.
- [ ] The user reviewed and approved the plan.

## References

- Definition of Done: `~/.agents/references/definition-of-done.md`
- Question format and decision log: `~/.agents/references/question-format.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- Step file template: `assets/step-file.md`
- Flow overview template: `assets/flow-file.md`
- PRD template (owned by `spec`): `../spec/assets/prd-file.md`
- Global plan config: `~/.agents/plans.config.md`
- Plan adapter operations: `~/.agents/plan-adapters/<adapter>/<operation>.md`
