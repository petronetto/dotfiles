---
name: verify-change
description: Verify implementation matches change artifacts. Use when the user wants to validate that implementation is complete, correct, and coherent before archival. Also use for "verify-change" or "verify change".
license: MIT
compatibility: Requires the plan adapter at ~/.agents/plan-adapters/plan.
metadata:
  author: openspec
  version: "1.0"
---

Verify that an implementation matches the change artifacts (specs, tasks, design).

**Storage selection and project check:** Read `../../plan-adapters/change-workflow.md` before starting. It replaces CLI storage, status, and instruction discovery only. Preserve this skill's verification workflow and the selected schema's artifact formats. `plan-cli` means `~/.agents/plan-adapters/plan`. Use the configured `PLAN_BACKEND` and `~/.agents/plans.config.md` (or `$PLAN_CONFIG`), never a hard-coded directory. Resolve existing changes and main specs with `plan-cli list`. Do not initialize anything during verification. Stop on backend errors without falling back to another directory.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use its location from `plan-cli list`. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, list available changes and ask the user to select one

   When prompting, show all active changes, including those without tasks. Include the schema for each when available. Mark changes with incomplete tasks as "(In Progress)".

   Always announce: "Using change: <name>" and how to override (e.g., `/verify-change <other>`).

2. **Check status to understand the schema**

   Run `plan-cli files <location>`, read `.change.yaml`, and derive status using the shared reference and selected schema. Understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context
   - Which artifacts exist for this change and which were deliberately skipped

3. **Get planning context and load artifacts**

   Derive the apply view from the selected schema and actual adapter reads, as described in the shared reference. Read all available `contextFiles` through the adapter. Use `taskTrackingConfigured` and aggregate `tasks` and `progress` from every readable file matched by `apply.tracks`, not just a file named tasks.md.

   Treat apply state and instruction as context, not a verification verdict. Do not implement tasks, update checkboxes or metadata, or archive during verification.

4. **Initialize verification report structure**

   Use three dimensions:
   - **Completeness**: Tasks and spec coverage
   - **Correctness**: Requirement implementation and scenario coverage
   - **Coherence**: Design adherence and pattern consistency

   Each dimension can have CRITICAL, WARNING, or SUGGESTION issues.

   Verification is advisory. Respect intentional omissions such as `skip_specs: true`, optional design documents, and schemas without task tracking. Do not require or invent optional or intentionally omitted artifacts to obtain a clean report. `Not verified` describes a limit of this report, not a new archival prerequisite. The user's archival process retains its own checks and confirmation behavior.

   Mark checks the schema does not define, or artifacts intentionally skipped, as **Not applicable**. Correctness checks for readable delta specs containing REMOVED or RENAMED requirements but no ADDED or MODIFIED requirements are also **Not applicable** (see step 6). Exclude them from skipped-check counts and readiness assessment. Reserve **Not verified** for applicable checks whose evidence is missing or unusable.

   If only task evidence is available for applicable checks, verify task completion only and mark the remaining applicable checks, including **Code Pattern Consistency**, not verified with the reason "Only task evidence available".

   If artifacts cannot be read or contain no usable requirements, scenarios, or design decisions, mark affected checks not verified with the specific reason. Continue checks supported by remaining evidence, but a partially checked input set is not a fully verified check. Missing requirements affect Spec Coverage and Requirement Implementation Mapping; missing scenarios affect Scenario Coverage; missing design decisions affect Design Adherence.

5. **Verify Completeness**

   **Task Completion:**
   - If `taskTrackingConfigured` is false, report Task Completion as not applicable. Do not treat empty tasks as missing evidence
   - Otherwise, use aggregate tasks and progress across all readable files matched by `apply.tracks`, regardless of artifact ID; do not infer tracking from a context-files key
   - If `unavailableTrackingFiles` is nonempty, mark Task Completion not verified and include every unavailable path and reason. Continue using readable task evidence, but do not infer completion from partial results
   - If tracking is configured and tasks are empty, mark Task Completion not verified and record the reason from the apply state and instruction. Nonzero totals alone do not establish evaluable task descriptions
   - Report complete versus total tasks
   - If remaining is greater than zero, add a CRITICAL issue for each incomplete task. If the remaining count exceeds the listed incomplete descriptions, also report incomplete checkboxes without descriptions. Recommend adding descriptions and completing them. Do not infer completion from listed descriptions alone
   - Recommendation: "Complete task: <description>" or "Mark as done if already implemented". Do not mark it yourself

   **Spec Coverage:**
   - If specs are deliberately skipped, or the schema defines no spec artifact with output under `specs/`, report spec-dependent checks as not applicable
   - Artifact IDs come from the active schema. Identify spec artifacts by output paths, not a hard-coded ID. Read their files through the adapter
   - If applicable spec files are absent or empty, mark Spec Coverage, Requirement Implementation Mapping, and Scenario Coverage not verified; never treat them as clean
   - Extract all requirements headed `### Requirement:` and FROM:/TO: pairs under `## RENAMED Requirements`. Record whether each sits under ADDED, MODIFIED, REMOVED, or RENAMED Requirements. The section controls the check

   For each **ADDED or MODIFIED** requirement:
   - Search the implementation for the required behavior
   - For MODIFIED, check the full updated delta text, not the old baseline wording
   - If apparently unimplemented, add CRITICAL: "Requirement not found: <name>" with a specific implementation recommendation

   For each **REMOVED** requirement, invert the check:
   - A removal block carries a name and Reason/Migration notes, not the baseline behavior. Before searching code, read `<capability-path>/spec.md` from the configured main-spec catalog using `plan-cli read <specs-location> <capability-path>/spec.md`. Use the same full capability path as the delta and match requirement headings by normalized name, including near-equivalent names
   - Its body and scenarios are the evidence for behavior that must be gone; never search from the requirement name alone
   - If the main spec no longer has that requirement, recover the baseline from history in the repository that owns the catalog, not automatically the implementation repository. Follow the shared reference's history procedure. An empty git-log result for a wrong path is not proof of no baseline; re-check the path
   - A baseline that only restates its title, with no usable body or scenarios, is unusable evidence. If neither current catalog nor history provides a usable baseline, mark this entry's Spec Coverage not verified with the reason and stop this check. Do not search from the title or count the removal as passing
   - Search code for the actual baseline behavior. Matches in planning artifacts or docs, or in code serving only the Migration note or an ADDED requirement, are not sufficient by themselves. Report any code path still delivering the removed behavior, including a path shared with ADDED behavior
   - Finding no implementation is expected only after searching for the baseline behavior. Never call a REMOVED requirement "Requirement not found" or recommend implementing it
   - If behavior remains, add CRITICAL: "Removed requirement still implemented: <name>". Recommend removing the remaining implementation at specific file/line ranges, following the Migration note

   For each **RENAMED** FROM:/TO: entry:
   - Only the name changes; behavior stays. Check the TO requirement for unchanged behavior
   - Do not report FROM as missing or require code symbols, identifiers, or filenames to be renamed
   - If TO also appears under MODIFIED, check it there against the updated text and skip this duplicate rename check
   - Otherwise read the baseline under FROM, or under TO only if FROM is absent because the main spec is already synced. Its body and scenarios establish the behavior TO keeps
   - Search implementation for that behavior and assess whether it remains
   - If apparently absent, add CRITICAL: "Renamed requirement not found: <TO name>". Recommend restoring the behavior, since a rename must not change it
   - If the baseline cannot be found or read, mark this entry's Spec Coverage not verified and explain why. Never count an unchecked rename as passing

6. **Verify Correctness**

   If readable delta specs contain at least one REMOVED or RENAMED requirement and no ADDED or MODIFIED requirements, mark Requirement Implementation Mapping and Scenario Coverage **Not applicable**. The baseline checks in Spec Coverage establish the evidence for removal/rename-only changes. Entries already marked not verified stay not verified there. A spec with no parseable requirements is unusable, not removal-only: mark these checks not verified.

   **Requirement Implementation Mapping:**
   - For each ADDED or MODIFIED requirement, find implementation evidence and note file paths and line ranges
   - Assess whether implementation matches requirement intent
   - On divergence, add WARNING: "Implementation may diverge from spec: <details>" with a recommendation to check a specific file/line range against the named requirement

   **Scenario Coverage:**
   - For each `#### Scenario:` under ADDED or MODIFIED, check whether its conditions are handled in code and whether tests cover them
   - If apparently uncovered, add WARNING: "Scenario not covered: <name>" and recommend the specific test or implementation needed
   - Skip scenarios under REMOVED requirements; that behavior is meant to be gone

7. **Verify Coherence**

   **Design Adherence:**
   - If the schema defines no design artifact (neither ID `design` nor output ending in design.md), or it is deliberately skipped, report not applicable
   - For a readable design, extract key decisions from Decision, Approach, or Architecture sections and compare them with implementation
   - On contradiction, add WARNING: "Design decision not followed: <decision>". Recommend updating implementation or revising design.md through a separate authorized action
   - If applicable design is absent, empty, or has no usable decisions, mark Design Adherence not verified. With other supporting artifacts, Code Pattern Consistency still runs; task-only evidence stays limited to task completion

   **Code Pattern Consistency:**
   - If implementation changes cannot be identified, mark not verified and explain the missing evidence
   - Otherwise review new code against project naming, structure, and style patterns
   - For significant deviation, add SUGGESTION: "Code pattern deviation: <details>" with a specific existing pattern to follow

8. **Generate Verification Report**

   **Summary Scorecard:**

   ```markdown
   ## Verification Report: <change-name>

   ### Summary
   | Dimension | Status |
   |-----------|--------|
   | Completeness | X/Y tasks, N requirements |
   | Correctness | M/N requirements covered |
   | Coherence | Followed/Issues |
   ```

   In each Status cell, report checks that ran and `Not verified (<reason>)` for every applicable check lacking evidence. If all checks in a dimension were skipped, start with Not verified. Never score a skipped check as passing. Treat every not verified or partially verified check as skipped in the final assessment. Count only ADDED and MODIFIED in N. Report removals and renames separately, including baseline limitations. For removal/rename-only changes, Correctness reads `Not applicable (no ADDED or MODIFIED requirements)`.

   **Issues by Priority:**
   1. **CRITICAL** (must fix before archival): Incomplete tasks, missing requirement implementations, removed behavior still present, or lost renamed behavior. Give specific actionable recommendations
   2. **WARNING** (should fix): Spec/design divergences or missing scenario coverage. Give specific recommendations
   3. **SUGGESTION** (nice to fix): Pattern inconsistencies or minor improvements. Give specific recommendations

   **Final Assessment:**
   - CRITICAL issues: "X critical issue(s) found. Fix before archiving." Name every not-verified check and reason too
   - No critical issues, warnings present, no skipped checks: "No critical issues. Y warning(s) to consider. Ready for archive (with noted improvements)."
   - Only suggestions, no skipped checks: "No critical issues or warnings. Z suggestion(s) to consider. Ready for archive (with noted improvements)."
   - No issues or skipped checks: "All checks passed. Ready for archive."
   - Any skipped checks and no critical issues: do not claim readiness. Say "No critical issues found in the checks that ran. <checks> not verified: <reason>." Include warnings when present
   - Include the suggestion count whenever nonzero

   Readiness is advisory. Use the user's own archival process; do not invent an archive command or perform archival during verification.

**Verification Heuristics**

- **Completeness**: Focus on objective checklist items and requirements
- **Correctness**: Use search, path analysis, and reasonable inference without requiring perfect certainty; distinguish inferred implementation from passing runtime evidence
- **Coherence**: Look for substantial inconsistencies, not style nits
- **False Positives**: When uncertain, prefer SUGGESTION over WARNING, WARNING over CRITICAL
- **Actionability**: Every issue needs a specific recommendation and file/line references where applicable

**Output Format**

Use clear Markdown with a summary scorecard, grouped CRITICAL/WARNING/SUGGESTION issues, references such as `file.ts:123`, and specific actionable recommendations. Avoid vague suggestions such as "consider reviewing". Do not write a report file unless the user asks to save it.
