---
name: spec-plan
description: Break a feature or fix into small, ordered, reviewable step files before coding. Trigger on "plan", "spec", "design", "scope", "break down". Outputs Markdown steps only—never writes code.
argument-hint: "<feature or fix description>"
---

# Spec Plan

Break a feature or fix into tiny, reviewable step files. Plans only; implementation is separate (`spec-build` skill). State lives on disk; every run re-derives context from git and the filesystem.

## Hard rules

- Never write or edit code—output is Markdown only.
- Resolve every design decision with the user before writing.
- One responsibility per step; each step leaves the codebase working.
- Never delete an existing plan. Ask before resuming or starting a new one.

## Procedure

### 1. Establish context

- Get repo path, branch, commit style from git.
- Use sub-agents to explore the codebase enough to plan responsibly.
- Prefer quality and simplicity over development cost.

### 2. Interview the user

Interview until reaching shared understanding, walking each design branch. For each question, recommend an answer with reasoning, then ask to confirm or refine. If the codebase answers it, read instead of asking. Use `lavish` to present options. Ask one question at a time. Never proceed with unresolved decisions.

### 3. Choose the plan directory

```
<project-full-path>/.plans/<branch>/<task-name>/
```

`<task-name>` is a short git-safe slug. Create the directory if missing. If it exists with unfinished steps, ask whether to resume or start a new plan.

### 4. Write the plan summary

```
<project-full-path>/.plans/<branch>/<task-name>/summary.md
```

Fill in the template at `assets/summary-file.md`: the problem, goals, non-goals,
approach, and the key decisions resolved during the interview. This is the
durable context step files link back to instead of restating.

### 5. Decompose into ordered steps

Break work into tiny, independently-reviewable steps. Each has one responsibility, can be reverted alone, and leaves the codebase working. Keep independent steps independent and record real dependencies in `Depends`; steps with no dependency between them can be built in parallel. Every chunk must deliver a working change on its own, no scaffolding-only chunks (e.g. enums or types nothing consumes yet). Prefer reframings that delete complexity over rearranging it (see `references/code-quality.md`).

### 6. Write one file per step

```
<project-full-path>/.plans/<branch>/<task-name>/NNN-<step-name>.md
```

Fill in the template at `assets/step-file.md` for each step (NNN = zero-padded ordinal from 000). Update the summary's "Steps" list to match.

### 7. Present and stop

Summarize the plan and list files created. Do not implement. Hand off to `spec-build` only after approval.

## References

- Design and code-quality standards: `references/code-quality.md`
- Plan summary template: `assets/summary-file.md`
- Step file template: `assets/step-file.md`
