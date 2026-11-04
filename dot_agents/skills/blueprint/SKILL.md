---
name: blueprint
description: Plan a whole new project from scratch before any epic exists. Interview for vision, stack, and constraints, then write CHARTER.md and ROADMAP.md in the roadmap location and hand each epic to propose. Trigger on "blueprint", "greenfield", "new project from scratch", "plan the whole project", or "roadmap". Markdown only, never code.
argument-hint: "<project idea>"
---

# Blueprint

Turn a new project idea into a charter and a shallow epic roadmap. Each epic
then goes through `/propose` and `/build` or `/build-auto`. Keep each change
small enough to reason about alone. Project state lives in the fixed
`roadmap` location, independent of branches.

Only blueprint maintains `CHARTER.md`, `ROADMAP.md`, `DECISIONS.md`, and ADR
entries in `CONTEXT.md`. An architecture decision record (ADR) captures a
choice with real alternatives that constrains several epics. Do not create
separate ADR files or change-level decision/evidence records.

## Input

A whole new project idea and the user's constraints. Route feature-level
work or a substantial existing codebase to `/propose` instead. On an existing
roadmap, this skill re-plans what remains; it does not overwrite history.

## Steps

### 1. Establish context and storage

Get the repository path from git. For greenfield work, use the idea, user
constraints, current stack documentation through `/find-docs`, and relevant
prior art. Record findings for the charter's Research and Assumptions.
Prefer a solution that removes complexity, following
`../../references/code-quality.md`.

Read `../../plan-adapters/change-workflow.md` for the adapter contract.
`plan-cli` means `~/.agents/plan-adapters/plan`. Use it for every artifact
operation, with `PLAN_BACKEND` and `~/.agents/plans.config.md` or `$PLAN_CONFIG`.
Get locations from `list` or `init`, never hand-built paths. Stop on backend
errors. For authorized blueprint creation, run `plan-cli init roadmap`.
The task name is always `roadmap`, never a branch-derived name.

Read any existing `CHARTER.md` and `ROADMAP.md` through the adapter. Ask
whether to re-plan remaining epics or start a new charter without destroying
existing content. Never delete a charter, roadmap, or epic row.

### 2. Interview

Ask one question at a time using `../../references/question-format.md` and
the harness question tool. Cover vision, users and their jobs, goals and
non-goals, platform/deployment/privacy/license/performance constraints,
stack and architecture, project layout, and test strategy. Research current
docs before proposing stack choices; do not rely on memory alone.

Append each answer to `DECISIONS.md` through `plan-cli append`, with an
`**Evidence:**` link to research or a note that it is a user preference.
Resolve every stack and architecture decision before drafting the charter.
Do not proceed on a guess or leave an open assumption.

### 3. Write the charter and project decisions

Fill `assets/charter-file.md` and save `CHARTER.md` through `plan-cli write`.
Include concrete vision, users, goals, non-goals, hard constraints, stack
choices with reasons and traceability, project-wide Always / Ask first /
Never boundaries, layout, test strategy, research, and resolved assumptions.

Promote a decision to an ADR only when at least two real alternatives were
considered and it constrains more than one epic. Read existing `CONTEXT.md`
through the adapter. If needed and absent, create a short document with
project metadata (`Task: roadmap`) and an Architecture decision records
section. Insert entries from `assets/adr-file.md`, preserving existing
content. Keep research and assumptions in the charter and link to them.
Do not create this document when no decision qualifies.

Use the next free ADR number with stable headings such as `### ADR-001`.
Link from the stack table and the original answer using
`[ADR-001](CONTEXT.md#adr-001)`, with `**Promoted to:**` on the answer.
Never change an accepted decision in place. Add its replacement, then update
only the old entry's Status and Superseded by fields. Use no target ADR count.

### 4. Decompose and write the roadmap

Use `assets/roadmap-file.md` for `ROADMAP.md`. Each epic has an immutable ID
such as E01, one-line intent, explicit in/deferred scope, dependencies, status
`planned`, and an empty Change column until `/propose` runs.

The first epic is a walking skeleton: tooling, CI, and one thin vertical
slice running end to end. Each later epic owns a capability and leaves
something demonstrable on its own. Keep dependencies real and acyclic.
Independent epics can be proposed and built in parallel worktrees.

Keep the roadmap shallow: no schemas, endpoints, file layouts, or design
inside rows. The charter holds project architecture; each change's optional
`design.md` holds its design. Split oversized epics into siblings, never
nested roadmaps. Do not create speculative future or contingency epics.
Add an ASCII dependency graph only if dependencies branch.

### 5. Check, present, and stop

Before handoff, confirm:

- The user reviewed and approved `CHARTER.md` and `ROADMAP.md`.
- Vision, users, goals, exclusions, and hard constraints are concrete.
- Project-wide Always / Ask first / Never boundaries are written.
- Stack decisions have reasons and traceability. Qualifying ADRs have stable
  heading links in `CONTEXT.md`, not separate files.
- No open assumption remains.
- Every epic has an immutable ID, sharp scope, one-line intent, and acyclic
  dependencies.
- The first epic is a walking skeleton; every epic is demonstrable alone.
- The roadmap contains no design detail.

Present the charter's key decisions and roadmap. Stop without implementing.
Hand the first epic whose dependencies are all done to `/propose`, with its
entry ID and roadmap location. `/propose` records `roadmap_entry` in change
metadata, sets the entry in-progress, and fills its Change column.

### 6. Re-plan on request

Read linked changes through the adapter and inspect their actual tasks and
verification evidence. Do not infer completion from artifact existence.
Refresh epic statuses with
`plan-cli set-status <roadmap-location> --entry <id> --status <status>`.
Supported statuses are planned, in-progress, done, and deferred.
Update the roadmap first for approved scope shifts, then the affected change
artifacts within authorized scope. Split or add epics as needed. Preserve
rows and referenced IDs; defer work rather than erase it.

## Output

Report the charter and roadmap location, decisions, epic order, approval
status, and next epic for `/propose`. List `CHARTER.md`, `ROADMAP.md`,
`DECISIONS.md`, and `CONTEXT.md` only when ADR entries were needed.

## Guardrails

- Markdown only; never implement code here.
- Resolve project decisions before charter approval. Do not defer stack
  choices that constrain all epics to the first change.
- Every epic must fit one proposal/build cycle and have a sharp scope.
- Keep project architecture in one place and epic design outside the roadmap.
- Apply YAGNI: extra epics add work and review cost, not automatic safety.
- Use ASD-STE100, define necessary terms, use ASCII diagrams, and use no em
  or en dashes. Keep project decision records only in this workflow.
