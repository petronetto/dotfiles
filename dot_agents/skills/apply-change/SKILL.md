---
name: apply-change
description: Implement tasks from a change. Use when the user wants to start implementing, continue implementation, or work through tasks. Also use when the user says "apply change", "apply-change", or "apply tasks".
license: MIT
compatibility: Requires the plan adapter at ~/.agents/plan-adapters/plan.
metadata:
  author: openspec
  version: "1.0"
---

Implement tasks from a change.

**Storage selection and project check:** Read `../../plan-adapters/change-workflow.md` before starting. It replaces CLI storage, status, and instruction discovery only. Preserve this skill's workflow and the selected schema's artifact formats. `plan-cli` means `~/.agents/plan-adapters/plan`. Use the configured `PLAN_BACKEND` and `~/.agents/plans.config.md` (or `$PLAN_CONFIG`), never a hard-coded directory. Resolve existing changes through `plan-cli list`; do not create a root or initialize a change as a side effect. Stop on backend errors. For an absent change, offer proposal creation and wait for the user.

**Input**: Optionally specify a change name (e.g., `/apply-change add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use its location from `plan-cli list`. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, list available changes and ask the user to select one

   Always announce: "Using change: <name>" and how to override (e.g., `/apply-change <other>`).

2. **Check status to understand the schema**

   Run `plan-cli files <location>`, read `.change.yaml`, and derive status using the shared storage reference and selected schema. Understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - `planningHome`, `changeRoot`, and `actionContext`: planning scope and edit constraints
   - Which artifact contains the tasks (typically "tasks" for spec-driven, check the schema for others)

3. **Get apply instructions**

   Read the schema's `apply` instruction and aggregate its tracking files through the adapter as specified in the shared reference. This supplies the working view of:
   - `contextFiles`: artifact ID to relative file paths (varies by schema)
   - Progress (total, complete, remaining)
   - Task list with status, source path, and source line
   - Instruction based on current state
   - Optional project `context` and `operationGuidance`
   - `missingArtifacts` when required artifacts have no output

   **Handle states:**
   - If `state: "blocked"`: show the message and pause implementation.
     - If `missingArtifacts` is non-empty: suggest using `/continue-change` to create them.
     - Otherwise, create or repair the schema-configured tracking file from existing planning artifacts. Do not assume another artifact is ready or start implementation while blocked.
   - If `state: "all_done"`: report that all tracked tasks are complete and suggest review or verification as appropriate before the user's archival process.
   - Otherwise: proceed to implementation.

   Treat `context` as a required prompt-level input when supplied. Apply relevant project facts, conventions, and constraints while implementing. Treat `operationGuidance` as optional additive advice. Consider every entry and follow those compatible with the workflow.

   Keep context and guidance separate from state, missing artifacts, tasks, progress, context files, and the schema instruction. They are not evidence of task completion and do not permit bypassing a blocked state. Report conflicts with an explicit user choice, the workflow, or actual adapter data. Preserve the controlling value and explain why conflicting guidance was not followed.

4. **Read context files**

   Read every file listed under `contextFiles` with `plan-cli read <location> <relative-file>`.
   - **spec-driven**: proposal, specs, design when applicable, tasks
   - Other schemas: use their resolved context files

   Do not copy context or operation guidance verbatim into implementation files or planning artifacts unless the user separately asks for that content.

5. **Show current progress**

   Display:
   - Schema being used
   - Progress: "N/M tasks complete"
   - Remaining tasks overview
   - Current apply instruction

6. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on
   - Make the code changes required
   - Keep changes minimal and focused
   - Before editing, re-read its `sourcePath` through the adapter and confirm the checkbox at `line` still matches the task description; if not, refresh the task view
   - Mark the task complete at its exact source path and line: `- [ ]` to `- [x]`. Use `plan-cli read` and `write` to save the full revised tracking file, preserving all other content
   - Refresh apply state and confirm that task is now done and progress changed
   - Continue to next task

   **Pause if:**
   - Task is unclear: ask for clarification
   - Implementation reveals a design issue: suggest updating artifacts
   - A task needs work beyond what the spec and tasks describe, or you are tempted to drop, narrow, defer, or accept exceptions to specified behavior to make it fit: surface the added scope and ask; do not absorb it silently
   - Error or blocker encountered: report and wait for guidance
   - User interrupts

7. **On completion or pause, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - If all done: report that tracked tasks are complete and suggest review or verification as appropriate before archival
   - If paused: explain why and wait for guidance

**Output During Implementation**

```text
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
Task complete

Working on task 4/7: <task description>
[...implementation happening...]
Task complete
```

**Output On Completion**

```text
## Implementation Complete

Change: <change-name>
Schema: <schema-name>
Progress: 7/7 tasks complete

### Completed This Session
- [x] Task 1
- [x] Task 2

All tracked tasks are complete. Review or verify the change as appropriate
before using your archival process.
```

**Output On Pause (Issue Encountered)**

Show the change, schema, progress, issue encountered, and possible approaches. Ask for the needed decision using the harness's question tool when available.

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting
- If task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements; do not guess
- When a task needs work beyond what the spec describes, surface the added scope and pause; never silently narrow, defer, or simplify away specified behavior
- Only mark a task complete when its specified behavior is fully implemented, not when it is partially done or deferred
- Use schema-resolved context files; do not assume specific filenames
- Use each task's source path and line to update its exact checkbox
- Do not use context or operation guidance as proof that a task is complete
- Apply relevant project context; report conflicts with controlling workflow inputs
- Consider every guidance entry; explain any inapplicable or conflicting advice
- Do not copy runtime context or operation guidance into implementation files or planning artifacts
- Preserve blocked/ready/all-done behavior and completion criteria
- Do not commit, archive, or delete files without authorization

**Fluid Workflow Integration**

This skill supports the "actions on a change" model:
- **Can be invoked anytime**: Before all artifacts are done (if the schema's apply prerequisites are satisfied), after partial implementation, interleaved with other actions
- **Allows artifact updates**: If implementation reveals design issues, suggest updating artifacts; not phase-locked, work fluidly
