---
name: blueprint
description: Plan a whole new project from scratch before any epic exists. Interview for vision, stack, and constraints, then write CHARTER.md (project constitution) and ROADMAP.md (shallow epic table) under .plans/roadmap/, and hand each epic to spec. Trigger on "blueprint", "greenfield", "new project from scratch", "plan the whole project", "roadmap". Markdown only, never code.
argument-hint: "<project idea>"
---

# Blueprint

Turn a project idea into a charter and an epic roadmap, so every later `spec` → `plan` → `build` cycle stays small. Use this for greenfield work where the request spans the whole project; feature-level work goes straight to `spec`. State lives on disk under `.plans/roadmap/`, branch-independent by design: the roadmap spans branches and outlives any single task. Output is Markdown only; implementation is separate (`spec`, then `plan`, then `build`, one epic at a time).

## Hard rules

- Never write or edit code; output is Markdown only.
- The roadmap is shallow: it names, bounds, and orders epics, and never designs them. Architecture lives in the charter and its ADRs; epic design lives in each PRD.
- Every epic boundary is sharp: one line of intent, explicit in/deferred scope, and something demonstrable when the epic alone is done.
- Interview one question at a time per `~/.agents/references/question-format.md`, appending each answer to `.plans/roadmap/decisions.md` with an `**Evidence:**` line. Resolve every stack and architecture decision with the user before writing the charter; never proceed on a guess.
- Prefer a reframing that deletes complexity over one that rearranges it (see `~/.agents/references/code-quality.md`).
- Never delete a charter, roadmap, or epic row. Epic IDs are immutable once referenced; scope shifts defer work, they do not erase it.
- A substantial existing codebase means this is not greenfield: route to `spec` instead.

## Gotchas

- "Start a new blueprint" on an existing roadmap means re-planning it (refresh statuses, re-decompose what remains), not overwriting it.
- Decompose only what the goals need (YAGNI): no v2 epics, no contingency epics. Add epics as learning grows.
- If an epic is still too large to spec in one cycle, split it into sibling epics; do not nest roadmaps. Go as deep as the context problem requires, no deeper.
- The roadmap directory is not branch-scoped. Do not derive it from git the way `plan-dir.sh` does.

## Available scripts

- **`scripts/roadmap-dir.sh`** — Computes (and optionally creates) `.plans/roadmap/` for the current repo. Unlike `plan-dir.sh`, the path is branch-independent on purpose.

## Procedure

### 1. Establish context
- Get the repo path from git. A fresh project has no codebase to explore; the discovery inputs are the user's idea, external research (use `/find-docs` for stack and tooling docs, plus prior art for the architecture), and the user's constraints.
- Record findings as you go. They land in the charter's Research and Assumptions sections: the charter is the project-level provenance record that every epic's PRD inherits from.

### 2. Decide the roadmap directory
Run `bash scripts/roadmap-dir.sh --create` to compute and create:
```
<project-full-path>/.plans/roadmap/
```
If the directory already holds a charter, ask whether to re-plan the remaining epics or start a new charter (see Gotchas), per `~/.agents/references/question-format.md`.

### 3. Interview the user
Cover, in order, one question at a time: vision (one paragraph in the user's terms), users and the job the project does for each, goals and non-goals, hard constraints (platform, deployment target, privacy, licenses, performance budgets), stack and architecture choices (research current docs before proposing; do not rely on training data), project layout, and test strategy. Log every answer in `decisions.md`, each with an `**Evidence:**` line to the research or a note that it is a pure user preference. Never proceed with an unresolved decision.

### 4. Write `CHARTER.md`
Fill `assets/charter-file.md` into `.plans/roadmap/CHARTER.md`: vision, users, goals, non-goals, hard constraints, the stack-decision table with rationale and traceability, project-wide boundaries (Always / Ask first / Never), layout and test strategy, research, and assumptions. Promote a decision to a standalone `ADR-NNN-*.md` (fill `../spec/assets/adr-file.md`, setting `Task` to `roadmap`) when it has real alternatives and constrains more than one epic; link it from the stack table. Most charters promote two to five ADRs; skip the ceremony when there are no real alternatives.

### 5. Decompose into epics
- The first epic is a walking skeleton: scaffold, tooling, CI, and one thin vertical slice running end to end.
- Then one epic per capability, each independently spec-able and each leaving something demonstrable.
- Record real dependencies; keep them acyclic. Independent epics can be specced and built in any order (in parallel across worktrees).
- Keep the set small; a typical project fits in a handful of epics. Split an oversized epic into siblings instead of designing it inside the roadmap.

### 6. Write `ROADMAP.md`
Fill `assets/roadmap-file.md` into `.plans/roadmap/ROADMAP.md`: one row per epic with ID (`E01`, immutable once referenced), name, intent, scope boundary (in / deferred), dependencies, status (`planned`), and PRD path (empty until `spec` runs). Include the flow graph only when dependencies branch.

### 7. Present and stop
Present the roadmap table and the charter's key decisions, and list the files created (`CHARTER.md`, `ROADMAP.md`, `decisions.md`, and any `ADR-NNN-*.md`). Do not implement. Hand off to `spec` for the first epic whose dependencies are all `done` (normally the walking skeleton), pointing it at the roadmap entry.

### 8. Re-plan on request
When invoked on an existing roadmap: refresh epic statuses from the PRDs and step files, apply scope shifts (update the roadmap first, then the affected PRDs), split or add epics as learning grows, and re-present the table. Never delete rows; defer instead.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "One giant PRD for the whole project is fine." | It forces every step file to reason over the whole contract and dies at context limits. A shallow roadmap plus one PRD per epic keeps every cycle small. |
| "The roadmap should contain the architecture." | The charter and its ADRs hold architecture; the roadmap holds boundaries and order. Designing in two places guarantees drift. |
| "Stack decisions can wait for the first PRD." | They constrain every epic. Deciding them late forces rework across PRDs already written. |
| "More epics is safer." | Each epic adds spec and review overhead. Decompose only as deep as the context problem requires. |
| "Plan v2 now so the roadmap is complete." | YAGNI. Add epics when learning justifies them. |

## Red flags

- A roadmap row containing design detail (schemas, endpoints, file layouts).
- Two epics sharing scope with no sharp boundary line.
- A charter written with unresolved stack choices or `open` assumptions.
- A first epic that is not a walking skeleton.
- An epic sized larger than one spec/plan/build cycle.

## Verification

Before handing off:
- [ ] The user reviewed and approved `CHARTER.md` and `ROADMAP.md`.
- [ ] Vision, users, goals, non-goals, and hard constraints are concrete.
- [ ] Project-wide boundaries (Always / Ask first / Never) are written.
- [ ] Stack decisions carry a one-line rationale and a traceability link; cross-epic ones are promoted to ADRs.
- [ ] No `open` assumption remains in the charter.
- [ ] Every epic has an immutable ID, a one-line intent, a sharp scope boundary, and recorded dependencies; dependencies are acyclic.
- [ ] The first epic is a walking skeleton, and every epic leaves something demonstrable.
- [ ] No design detail sits in the roadmap.

## References

- Question format and decision log: `~/.agents/references/question-format.md`
- Design and code-quality standards: `~/.agents/references/code-quality.md`
- Charter template: `assets/charter-file.md`
- Roadmap template: `assets/roadmap-file.md`
- ADR template (owned by `spec`): `../spec/assets/adr-file.md`
- Roadmap directory script: `scripts/roadmap-dir.sh`
- Per-epic pipeline: `spec` (PRD), `plan` (steps), `build` (implementation)