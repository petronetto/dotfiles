---
name: spec
description: Write a PRD for a feature or fix before coding, by interviewing the user one question at a time until shared understanding. Trigger on "spec", "requirements", "design the work", "scope it first". Produces the PRD that `plan` decomposes; outputs Markdown only, never code.
argument-hint: "<feature or fix description>"
---

# Spec

Specify what to build and why before any code. Interview the user one question at a time until you reach shared understanding, surface assumptions explicitly, and write the PRD that `plan` decomposes into steps. The PRD lives on disk and is the shared source of truth. Output is Markdown only; implementation is separate (`build`).

## Hard rules

- Never write or edit code—output is Markdown only.
- Interview one question at a time. For each, recommend an answer with reasoning, then ask to confirm or refine. If the codebase answers it, read instead of asking. Use `lavish` to present options.
- Surface assumptions explicitly and have the user correct them before proceeding.
- Resolve every open question and design decision with the user. Never proceed on a guess.
- Prefer a reframing that deletes complexity over one that rearranges it (see `~/.agents/references/code-quality.md`).
- Never delete an existing PRD. Ask before resuming a PRD that already has unfinished work or starting a new one.

## Procedure

### 1. Establish context
- Get repo path, branch, and commit style from git.
- Use sub-agents to explore the codebase enough to plan responsibly.
- Prefer quality and simplicity over development cost.

### 2. Decide the plan directory
```
<project-full-path>/.plans/<branch>/<task-name>/
```
`<task-name>` is a short git-safe slug. Create it if missing. If it already holds an unfinished PRD, ask whether to resume or start a new one. "Start a new one" means picking a different `<task-name>` slug, not overwriting the existing PRD in place — the hard rule against deleting an existing PRD also means never reusing its directory for unrelated work.

### 3. Surface assumptions
Before writing anything, list what you are assuming (platform, data model, auth, target environment, dependencies). Ask the user to correct any of them before you proceed. Don't silently fill ambiguous requirements.

### 4. Capability map (only when needed)
Most requests are one capability; skip this. If one request bundles several independently testable capabilities that could ship and be verified separately, first propose a small capability map (module ids, dependency direction with no cycles, build order), get it approved, then write a PRD per module in dependency order. Keep it to a module table and a build order, not a project plan.

### 5. Interview the user
Interview until you reach shared understanding, walking each design branch one question at a time. Use `lavish` to present options. Never proceed with unresolved decisions.

### 6. Write the PRD
Fill the template at `assets/prd-file.md` into `.plans/<branch>/<task-name>/PRD.md`. This is the PRD for the work. Cover, at minimum, problem and goals, non-goals, boundaries (Always / Ask first / Never), approach, the project commands, and the key decisions with why. Step files link back to it instead of restating it.

### 7. Present and stop
Summarize the PRD and list the file created. Do not implement. Hand off to `plan` only after approval.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "This is simple, no spec needed." | Simple work still needs a few lines of acceptance criteria and boundaries. A two-line PRD is fine. |
| "I'll write the spec after the code." | That's documentation, not specification. The PRD's value is forcing clarity before code exists. |
| "The user knows what they want." | Even clear requests carry implicit assumptions. Surfacing them up front is the whole point. |
| "It's one big feature; I'll keep it as one PRD." | If acceptance criteria cluster into independently testable groups, a monolithic PRD forces every step to reason over the whole contract. A small capability map is the cheap alternative. |
| "Planning is overhead." | Planning is the task. A 15-minute PRD prevents hours of rework. |

## Red flags

- Starting to code while requirements are still loose or assumed.
- Asking "should I just start building?" before "done" is clear.
- An unresolved question or decision passed by instead of resolved.
- One PRD whose scope spans several independently testable capabilities with no capability map.

## Verification

Before handing off to `plan`, confirm:
- [ ] The user reviewed and approved the PRD.
- [ ] Problem, goals, and non-goals are concrete.
- [ ] Boundaries (Always / Ask first / Never) are written.
- [ ] The project's build/test/lint commands are recorded.
- [ ] Key decisions are recorded with a one-line rationale each.
- [ ] Assumptions were surfaced and either corrected or accepted.
- [ ] `PRD.md` is saved under `.plans/<branch>/<task-name>/`.

## References

- Design and code-quality standards: `~/.agents/references/code-quality.md`
- PRD template: `assets/prd-file.md`
