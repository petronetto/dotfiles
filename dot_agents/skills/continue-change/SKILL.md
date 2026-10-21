---
name: continue-change
description: Continue working on a change by creating the next artifact. Use when the user wants to progress their change, create the next artifact, or continue their workflow. Also use for "continue-change" or "continue change".
license: MIT
compatibility: Requires the plan adapter at ~/.agents/plan-adapters/plan.
metadata:
  author: openspec
  version: "1.0"
---

Continue working on a change by creating the next artifact.

**Storage selection and project check:** Read `../../plan-adapters/change-workflow.md` before starting. It replaces CLI storage, status, and instruction discovery only. Preserve this skill's workflow and the selected schema's artifact formats. `plan-cli` means `~/.agents/plan-adapters/plan`. Use the configured `PLAN_BACKEND` and `~/.agents/plans.config.md` (or `$PLAN_CONFIG`), never a hard-coded directory. Resolve existing changes through `plan-cli list`; do not create a root or initialize a change as a side effect. Stop on backend errors. If no change exists, offer `/propose` and wait.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use its location from `plan-cli list`. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, get available changes, inspect their modification times as described in the storage reference, and ask the user to select one

   When prompting, present the top 3-4 most recently modified changes as options, showing:
   - Change name
   - Status (e.g., "0/5 tasks", "complete", "no tasks")
   - How recently it was modified, if available

   Mark the most recently modified change as "(Recommended)" when recency is known. Never infer recency from the sorted `list` output.

   Always announce: "Using change: <name>" and how to override (e.g., `/continue-change <other>`).

2. **Check current status**

   Run `plan-cli files <location>`, read `.change.yaml`, and derive status using the shared reference and selected schema:
   - `schemaName`: The workflow schema being used (e.g., "spec-driven")
   - `artifacts`: Artifacts with status ("done", "skipped", "ready", "blocked") and dependency edges
   - `isPlanningComplete`: Whether all planning artifacts are present or deliberately skipped
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context. Use these instead of assuming repository-local paths

3. **Act based on status**

   **Before anything else, finish a partly written artifact:**
   - An artifact whose output is a glob pattern (e.g. `specs/**/*.md`) reads `done` as soon as one matching file exists, so an interrupted run can leave some files missing
   - For each such `done` artifact, read its schema instruction and completed dependencies to determine the expected files. For spec-driven's `specs`, read the proposal and check for one `specs/<capability-path>/spec.md` per capability it lists. Compare with the actual relative paths from `plan-cli files`
   - Check every expected relative path against the selected change scope. The adapter rejects traversal and symlink paths; never work around a rejected path
   - If any are missing, write only the missing files with `plan-cli write <location> <relative-file>`. When the schema delegates creation, use it only if it can write each file through the selected adapter scope; otherwise stop and tell the user
   - STOP after repairing that ONE artifact. If you cannot tell whether a file was left out on purpose, ask the user

   **If all planning artifacts are complete (`isPlanningComplete: true`):**
   - Congratulate the user
   - Show final status including the schema used
   - Suggest: "Planning is complete! You can now implement this change. Once implementation and any tracked work are complete, use your archival process."
   - STOP

   **If artifacts are ready to create:**
   - Pick the FIRST artifact with status `ready` in schema order
   - Read its instruction and template from the selected schema, and its completed dependencies through `plan-cli read`
   - Apply project `context` and artifact `rules` as constraints, not output content
   - If the artifact is skipped, do not create it; pick another. If its own instruction is conditional, evaluate that condition. When it does not apply, record the deliberate skip in `.change.yaml` through the adapter, report why, and pick the next ready artifact
   - Choose the output path before creating anything. For a glob, use the schema instruction and proposal to choose a concrete relative path within the change
   - If the instruction delegates creation to another skill or command, invoke it only if it can preserve this schema, format, and adapter output scope; otherwise stop and tell the user
   - Otherwise, write it yourself:
     - Use the template as the structure and fill in its sections
     - Apply context and rules without copying instruction blocks into the file
     - Write with `plan-cli write <location> <relative-file>`
   - Either way, verify the artifact through `plan-cli read`
   - Show what was created and what is now unlocked
   - STOP after creating ONE artifact

   **If no artifacts are ready (all blocked):**
   - This should not happen with a valid schema
   - Show status and suggest checking for issues

4. **After creating an artifact, show progress**

   Refresh the adapter inventory and derive status again. Verify the output before marking progress. Do not count file presence as implementation completion.

**Output**

After each invocation, show:
- Which artifact was created
- Schema workflow being used
- Current progress (N/M complete)
- What artifacts are now unlocked
- Prompt: "Want to continue? Just ask me to continue or tell me what to do next."

**Artifact Creation Guidelines**

Artifact types and their purpose depend on the schema. Its `instruction` is the authoritative guidance for each artifact, even when it has a familiar name (proposal.md, tasks.md, etc.), since custom schemas may define different content or processes.

If the instruction directs creation through a specific skill or command, invoke it instead of writing directly, but only after checking the adapter output scope and confirming that the delegated workflow preserves the required format. Do not substitute the local `spec` or `plan` workflow.

**Guardrails**
- Create ONE artifact per invocation
- Always re-read dependency artifacts from storage, not conversation memory
- Never skip artifacts or create out of order, except for the schema's declared conditional skips
- If context is unclear, ask the user before creating
- Verify the artifact through the adapter before marking progress
- Use the schema's artifact sequence; do not assume specific artifact names
- Context and rules are constraints for YOU, not content for the file
- Do not copy `<context>`, `<rules>`, or `<project_context>` blocks into the artifact
- Do not implement or commit as part of continuing planning
