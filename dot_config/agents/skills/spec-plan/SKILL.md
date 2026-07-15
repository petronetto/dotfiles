---
name: spec-plan
description: Decompose a feature or fix into small, ordered, individually-reviewable step files before any code is written. Use when the user asks to plan, spec, design, scope, or break down work, or says "plan only", "just plan", "create a plan", "spec this", or "plan this feature". Produces one Markdown step file per step under a plan directory and stops. Never writes code.
argument-hint: "<feature or fix description>"
---

# Spec Plan

Turn a feature or fix into a sequence of tiny, reviewable step files. This skill plans only; it never writes code. Implementation is handled separately by the `spec-build` skill.

State lives on disk in the plan directory, not in the conversation. Every run re-derives its context from git and the filesystem.

## Hard rules

- Never write or edit code. Output is only Markdown step files.
- Resolve every significant design decision with the user before writing files.
- One responsibility per step; each step must leave the codebase working.
- Never delete an existing plan. Ask before resuming or starting a new one.

## Procedure

### 1. Establish context

- `git rev-parse --show-toplevel` → absolute repo path as `<project-full-path>`.
- `git rev-parse --abbrev-ref HEAD` → `<branch>`; slugify (lowercase, `/` and unsafe chars to `-`, collapse repeats).
- `git log --oneline -20` → learn commit-message style for later reuse.
- Explore the codebase enough to plan responsibly. Prefer quality, simplicity, and long-term maintainability over development cost.

### 2. Interview the user

Interview relentlessly until you reach shared understanding. Walk each branch of the design tree, resolving dependencies one decision at a time. For each open question, give your recommended answer with reasoning, then ask the user to confirm, override, or refine. If a question can be answered by reading the codebase, read it instead of asking. Use the `lavish` skill to present options. Do not proceed until every significant decision is resolved.

### 3. Choose the plan directory

```
<project-full-path>/.plans/<branch>/<task-name>/
```

`.plans/` may or may not be in `.gitignore`, so do not use git to search for plans. `<task-name>` is a short git-safe slug for the whole task. Create the directory if missing. If it already exists with unfinished step files, ask whether to resume (via `spec-build`) or start a new plan under a different `<task-name>`.

### 4. Decompose into ordered steps

Break the work into the smallest sequence of independently-reviewable steps. A good step has one responsibility, can be reviewed and reverted alone, leaves the codebase working, and moves toward the simplest viable design. Apply `references/code-quality.md`: prefer reframings that delete whole steps, branches, or layers over refactors that merely rearrange complexity.

### 5. Write one file per step

```
<project-full-path>/.plans/<branch>/<task-name>/NNN-<step-name>.md
```

`NNN` is a zero-padded ordinal from `000`. Fill in the template at `assets/step-file.md` for every step.

### 6. Present and stop

Give a short prose summary of the plan and the list of files created, then stop. Do not implement. Hand off to `spec-build` only after the user approves.

## References

- Design and code-quality standards: `references/code-quality.md`
- Step file template: `assets/step-file.md`
