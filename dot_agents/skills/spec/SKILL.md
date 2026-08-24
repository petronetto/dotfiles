---
name: spec
description: Write a PRD for a feature or fix before coding, by interviewing the user one question at a time until shared understanding. Trigger on "spec", "requirements", "design the work", "scope it first". Produces the PRD that `plan` decomposes; outputs Markdown only, never code.
argument-hint: "<feature or fix description>"
---

# Spec

Specify what to build and why before any code. Interview the user one question at a time until you reach shared understanding, surface assumptions explicitly, and write the PRD that `plan` decomposes into steps. The PRD lives on disk and is the shared source of truth. Output is Markdown only; implementation is separate (`build`).

## Hard rules

- Never write or edit code—output is Markdown only.
- Interview one question at a time using the format in `~/.agents/references/question-format.md`, appending each answer to the plan directory's `decisions.md`. If the codebase answers it, read instead of asking.
- Keep a discovery record: from the first exploration, record what you investigated, where, with which tools, what you found, and which findings informed which decisions in the plan directory's `CONTEXT.md`. It is the provenance layer that makes the PRD debuggable.
- Surface assumptions explicitly and have the user correct them before proceeding.
- Resolve every open question and design decision with the user. Never proceed on a guess.
- Prefer a reframing that deletes complexity over one that rearranges it (see `~/.agents/references/code-quality.md`).
- Never delete an existing PRD. Ask before resuming a PRD that already has unfinished work or starting a new one.

## Gotchas

- "Start a new one" means picking a different `<task-name>` slug — never overwriting or reusing an existing PRD's directory for unrelated work, even when the user says "start fresh."

## Available scripts

- **`scripts/plan-dir.sh`** — Computes (and optionally creates) the plan directory path for the current repo, branch, and task name, so it always matches `plan`'s.

## Procedure

### 1. Establish context
- Get repo path, branch, and commit style from git.
- Use sub-agents to explore the codebase enough to plan responsibly.
- Prefer quality and simplicity over development cost.
- Begin the discovery record now: capture every investigation (path, tool,
  finding, implication) so nothing is lost to the session transcript. The
  record is committed to disk in step 2 as `CONTEXT.md`.

### 2. Decide the plan directory
Run `scripts/plan-dir.sh <task-name> --create` to compute and create:
```
<project-full-path>/.plans/<branch>/<task-name>/
```
`<task-name>` is a short git-safe slug; the script validates it. If it already holds an unfinished PRD, ask whether to resume or start a new one (see Gotchas).

### 3. Write `CONTEXT.md`
Fill the template at `assets/context-file.md` into
`.plans/<branch>/<task-name>/CONTEXT.md` with the discovery record begun in
step 1: the request in the user's terms, the codebase exploration, external
research, the assumptions table, constraints discovered, open gaps, and a
provenance map linking findings to the decisions they will inform. Refine it
as understanding grows; freeze it when the PRD is approved. This is the
provenance layer that lets a human debug why the PRD says what it says.

### 4. Surface assumptions
Before interviewing, list what you are assuming (platform, data model,
auth, target environment, dependencies) and write each into `CONTEXT.md`'s
Assumptions table with status `open` or `accepted`. Ask the user to correct
any of them before you proceed; move corrected ones to `validated` or
`corrected`. Don't silently fill ambiguous requirements.

### 5. Capability map (only when needed)
Most requests are one capability; skip this. If one request bundles several independently testable capabilities that could ship and be verified separately, first propose a small capability map (module ids, dependency direction with no cycles, build order), get it approved, then write a PRD per module in dependency order. Keep it to a module table and a build order, not a project plan.

### 6. Interview the user
Interview until you reach shared understanding, walking each design branch one question at a time per `~/.agents/references/question-format.md`, appending each answer to `.plans/<branch>/<task-name>/decisions.md`. Every entry carries an `**Evidence:**` line linking back to the `CONTEXT.md` topic or provenance row that informed it. Never proceed with unresolved decisions.

### 7. Promote cross-cutting decisions to ADRs
For each decision that meets both tests, (a) two or more real alternatives
were considered and (b) it constrains more than one plan step, promote the
`decisions.md` entry into a standalone ADR by filling
`assets/adr-file.md` as `ADR-NNN-<slug>.md` in the plan directory
(NNN = next free ordinal). Add `**Promoted to:** ADR-NNN` to the original
`decisions.md` entry. ADRs are immutable once Accepted; to change one,
write a new ADR that supersedes it. Most specs produce zero to two ADRs;
skip the ceremony for decisions with no real alternatives.

### 8. Write the PRD
Fill the template at `assets/prd-file.md` into `.plans/<branch>/<task-name>/PRD.md`. This is the PRD for the work. Cover, at minimum, problem and goals, non-goals, boundaries (Always / Ask first / Never), approach, the project commands, and the key decisions table with one-line rationale and a traceability link (`Q#` / `ADR-NNN` / `CONTEXT.md` topic) per decision. Step files link back to it instead of restating it.

### 9. Present and stop
Summarize the PRD and list the files created (`PRD.md`, `CONTEXT.md`, `decisions.md`, and any `ADR-NNN-*.md`). Do not implement. Hand off to `plan` only after approval.

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
- [ ] Key decisions are recorded with a one-line rationale and a traceability link each.
- [ ] `CONTEXT.md` captures the request, codebase exploration (with provenance), external research, assumptions, constraints, gaps, and the provenance map.
- [ ] Every interview question and answer is logged in `decisions.md`, each entry carrying an `**Evidence:**` (or `**Promoted to:** ADR-NNN`) line.
- [ ] Cross-cutting decisions with real alternatives were promoted to `ADR-NNN-*.md`; the corresponding `decisions.md` entries note the promotion.
- [ ] Assumptions were surfaced and either corrected or accepted.
- [ ] `PRD.md` is saved under `.plans/<branch>/<task-name>/`.

## References

- Question format and decision log: `~/.agents/references/question-format.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- PRD template: `assets/prd-file.md`
- Context (discovery) template: `assets/context-file.md`
- ADR template: `assets/adr-file.md`
- Plan directory script: `scripts/plan-dir.sh`
