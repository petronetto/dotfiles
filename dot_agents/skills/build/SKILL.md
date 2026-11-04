---
name: build
description: Implement a change one task group at a time, stopping for explicit approval before committing each group. Use when the user wants to build, implement, resume implementation, or work through change tasks.
license: MIT
compatibility: Requires the plan adapter at ../../plan-adapters/plan.
metadata:
  author: openspec
  version: "1.0"
---

Implement tasks from a change, with a human approval gate after each task group.

Read `../../plan-adapters/change-workflow.md` before starting. `plan-cli` means
`../../plan-adapters/plan`. Use the configured `PLAN_BACKEND` and
`../../plans.config.md` (or `$PLAN_CONFIG`), never a hard-coded directory.
Resolve existing changes through `plan-cli list`. Do not initialize a change
as a side effect. Stop on backend errors. For absent artifacts, point to
`/propose` and wait for the user.

## Input

Optionally specify a change name, such as `/build add-auth`. Infer it from
conversation context or select the only active change. If ambiguous, list
available changes and ask with the harness's question tool. Announce
"Using change: <name>" and how to override it with `/build <other>`.

## Steps

### 1. Derive apply state

Run `plan-cli files <location>`, read `.change.yaml`, and derive status from
the selected schema and shared storage reference. Read `schemaName`,
`planningHome`, `changeRoot`, and `actionContext`. Identify the schema's
tracking artifact rather than assuming a filename.

Read the schema's `apply` instruction and aggregate tracking files through
the adapter. Obtain `contextFiles`, tasks with `sourcePath` and line, progress,
state, instruction, `missingArtifacts`, optional project `context`, and
`operationGuidance`.

- `blocked`: show the reason and pause. If artifacts are missing, point to
  `/propose`. Otherwise repair the schema's tracking file from existing
  artifacts within authorized scope; do not implement while blocked.
- `all_done`: tracked tasks are complete, not proof that the change is done.
  Go to the final audit rather than implement more work.
- `ready`: proceed with the next pending group.

Treat project context as a required prompt input when supplied, and guidance
as optional additive advice. Consider every guidance entry. Report conflicts
with user choices, the workflow, or actual adapter data; preserve the
controlling value and explain advice not followed. Neither context nor
guidance is evidence of completion or permission to bypass a blocked state.

### 2. Read context and discover checks

Read every `contextFiles` entry with `plan-cli read`. For spec-driven changes,
these are proposal, specs, design when applicable, and tasks. Use the resolved
files for other schemas. Do not copy runtime context or operation guidance
verbatim into code or artifacts.

Read project instructions and, if a roadmap exists, `CHARTER.md` through the
adapter. Discover build, test, lint, and runtime commands from the stack,
README, wrappers, and CI. Do not guess defaults.

Load `../../references/code-quality.md`, `reuse-checklist.md`,
`uncertainty-protocol.md`, `question-format.md`, and `definition-of-done.md`.
Use the `test` skill for behavior changes and bug fixes. Apply its failing-test
first discipline, Arrange-Act-Assert, and external test doubles.

Show the schema, "N/M tasks complete", remaining groups, dependencies, and
current apply instruction. Resume at the first group with unchecked tasks.
If it has partial work (checked tasks or relevant uncommitted changes), show
the group and current diff and ask whether to resume or restart. Do not
silently skip it or discard work. A restart requires explicit authorization
for the specific changes to undo; protect unrelated user changes.

### 3. Implement one task group

Read its plain `Depends:` line. Prerequisites must be complete. Missing,
cyclic, or unclear dependencies are a reason to pause, not guess.

Announce the group and goal. Work in small, focused chunks that each leave
the code working. Do not add scaffolding that nothing consumes. Preserve
existing behavior unless the change explicitly requires otherwise. Apply
code-quality and the reuse checklist before adding code. Do not add unrelated
cleanup or silently reduce specified behavior.

For each task:

- Make the minimal scoped change and run its checks. For new or changed
  behavior, prove a test failed before and passes after. Reproduce bugs in
  tests before fixing them. Do not defer tests until the last group.
- Before a checkbox edit, re-read its `sourcePath` through the adapter and
  confirm the line and description still match. Refresh the view on drift.
- Mark only fully implemented and verified tasks complete at their exact
  source line. Use `plan-cli read` and `write` for the full revised tracking
  file, preserving other content.
- Refresh apply state and confirm the task and progress changed.

Run the project's tests and linters, piping long output. Verify behavior at
runtime, not just by compiling or typechecking. Use `agent-browser` for
browser behavior. Check the entire Definition of Done per group, including
integration, documentation, security, and rollback where applicable. Report
inapplicable checks with reasons rather than invent work.

### 4. Stop for explicit approval

Show the group's diff, checks and runtime evidence, scope, and any issues.
Stop after each task group for explicit approval. Do not commit or start the
next group before that approval. Checked tasks alone do not satisfy this gate.

If modifications are requested, implement them in small working chunks,
repeat checks, and stop again. Keep decisions in the conversation; no extra
review or decision files. Follow the uncertainty protocol: unclear approval,
failing or skipped checks, unexpected diffs, and unclear scope require a
focused question. Silence is not approval.

With unambiguous approval to commit this group, stage only that group's files
and inspect the staged diff. Use the project's commit style and no co-author
trailers. Never mention the plan, task, group, or chunk in commit messages or
code comments; describe the actual code change. Do not include unrelated
changes even when they share a file. If staging cannot isolate the change,
pause. Move to the next group only after approval and the scoped commit.

On resumption, inspect git and artifacts, not session memory. If all tasks in
a group are checked but its approval or commit is unproved, resolve that gate
before advancing. Do not silently treat checkboxes as approval.

### 5. Run the final audit

After the last group, run `../../references/final-audit.md` read-only against
the delivered code and artifacts. For a pure refactor, audit preservation
checks. CRITICAL findings and applicable `Not verified` checks block done.
Return them to the same fix, verification, explicit approval, and scoped
commit loop. Reopen affected checkboxes when work remains, and re-run the
audit after fixes. WARNING and SUGGESTION findings are reported only.

Only after all groups have cleared their gates and no audit blocker remains,
read `roadmap_entry` from `.change.yaml`. If present, resolve the roadmap
location with `plan-cli list` and run
`plan-cli set-status <roadmap-location> --entry <id> --status done`.
Do not mark a linked epic done on partial or unchecked evidence.

## Output

On a group stop, report the change, schema, completed tasks and overall
progress, changed files, check results, and the explicit approval needed.
On an issue, explain the blocker and available choices and wait for guidance.
On completion, report changes, rationale, commits, final audit findings,
roadmap status if linked, and unresolved warnings or suggestions.

## Guardrails

- Pause on unclear tasks, design issues, errors, blockers, or interruption.
- If work exceeds the specs or tasks, surface the added scope and ask. Never
  silently drop, narrow, defer, or accept exceptions to required behavior.
- Read context before editing. Preserve schema-resolved state and tracking.
- Only mark fully implemented behavior complete, not partial or deferred work.
- Do not advance or commit without explicit group approval and passing checks.
- Per-group checks do not replace the final audit. Report unrequested work;
  never delete it during the audit.
- Do not archive or delete files without authorization. Suggest `/propose`
  for missing artifacts; do not invent a different artifact format.
