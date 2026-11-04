---
name: build-auto
description: Autonomously implement change task groups using fresh builder and reviewer sub-agents, with review, fixes, and one commit per group. Trigger on "build-auto", "autopilot", "ship the plan", or "run the plan". No human checkpoint between groups.
---

# Build Auto

Implement a change through independent builder and reviewer loops. The unit
is a task group, not an individual checkbox. The reviewer is the gate; the
orchestrator does not replace independent judgment.

Read `../../plan-adapters/change-workflow.md` first. Use `plan-cli`
(`../../plan-adapters/plan`) with the configured backend and
`../../plans.config.md` or `$PLAN_CONFIG`. Use the adapter for all artifact
operations. Stop on backend errors; do not initialize missing work.

## Input

A change name or enough context to select an existing change. Use
`plan-cli list`, exclude unrelated locations, and ask which change to run
only if selection is ambiguous. This sets the scope of the unattended run.
Missing artifacts go to `/propose`, not invented requirements.

## Steps

### 1. Read the change and discover the stack

Read `.change.yaml`, the schema, and all resolved context files through the
adapter. Derive apply state, tasks, and progress as in the shared reference.
Respect blocked/ready/all_done state and skipped artifacts. Read proposal,
specs, design when present, and task groups. If tracking is unusable or
required artifacts are missing, report the blocker before launching children.
An all_done apply view still requires the final audit.

Read project instructions and the roadmap's `CHARTER.md` through `plan-cli`
when present. Gather project standards once: stack discovery through `test`,
README, build wrappers, CI, lint configuration, and charter constraints.
Do not invent commands or take boundaries from a change-specific document.

Inspect git, relevant diffs, and existing worktrees for partial work. Preserve
it as the builder's starting point, not contamination to discard. Do not
include unrelated user edits. Re-derive context every run, not from memory.

### 2. Schedule task groups

Read each plain `Depends:` line. Dependencies must exist and be acyclic.
Work incomplete groups in dependency order. Groups with no dependency
between them and disjoint files may build in parallel. Include tests and
shared configuration in the file-overlap check.

Keep blocked groups and reasons in memory for this run only. Skip groups
that depend directly or transitively on a blocked group; report them. Other
independent groups may continue. Do not save blocked state in artifacts or
metadata. Leave unresolved work unchecked. The next run tries it again with
fresh evidence and a new bounded attempt.

Use Worktrunk (`wt`) for parallel isolation, not shared uncommitted edits:

```sh
wt switch --create <group-branch> --base <target-branch> --no-cd
wt list --format=json
```

Resolve the returned worktree path for each branch. On resumption, reuse the
existing branch/worktree only after inspecting it; do not overwrite it.
Every concurrent builder gets its own worktree. A lone builder may use the
main working tree. Keep the target tree free of unrelated edits and serialize
integration. Only the orchestrator updates shared task checkboxes, so parallel
children do not race on planning storage.

### 3. Build, review, and fix

For each group, allow at most **3 build-to-review cycles**:

1. Announce the group and goal. Spawn a fresh builder sub-agent using
   `assets/builder-brief.md`. Include proposal, applicable specs, design when
   present, the task group, project standards, code-quality, reuse checklist,
   and Definition of Done. On retry, include the current findings. The builder
   implements small working chunks, applies `test`, runs tests and linters,
   and verifies runtime behavior. It does not stage or commit.
2. Spawn a fresh reviewer sub-agent using `assets/reviewer-brief.md`. It runs
   `review` at medium effort and separately checks the group contract,
   behavior, test evidence, reuse checklist, and full Definition of Done.
   The `review` skill itself does not check specs. The reviewer only judges:
   no fixes, file edits, `--fix`, or `--comment`.
3. Accept only a first-line `VERDICT: APPROVE` or
   `VERDICT: CHANGES_REQUESTED`. Missing or malformed approval is not approval.
   The reviewer must confirm new/changed behavior has a test that failed
   before and passes after, passing tests and linters, runtime evidence,
   scope, and the full Definition of Done.
4. For changes requested or a builder blocker, send findings to a new builder
   if cycles remain, then use a new reviewer. After cycle 3, keep the group
   unresolved in memory, do not commit it as complete, and skip its dependents.
   Do not pause for a human decision in the middle of the run.

Keep the orchestrator context small: group progress, current verdict/findings,
commit IDs, and blockers, not full diffs or logs. Children receive only the
current group's context and applicable standards, not the orchestrator's
history or other groups' details. Do not write a review log. Verdicts appear
only in the final report, not in artifacts or progress announcements.

### 4. Commit and integrate an approved group

Only after `VERDICT: APPROVE`, inspect and stage that group's files and make
one commit per group in project style, with no co-author trailer. Never name
the plan, task, group, or chunk in commit messages or code comments. Preserve
unrelated edits even in shared files; if isolation is impossible, block the
group rather than include them.

For parallel work, bring the approved commit onto the latest target before
integration, using `wt -C <worktree> step rebase <target-branch>` if needed.
After rebasing, run integration checks and get a fresh reviewer judgment on
the resulting diff before advancing the target. Rework caused by integration
uses the same remaining 3-cycle budget; do not reset it. Amend only this run's
unpublished group commit after approval, so the group remains one commit.
Do not rewrite pre-existing user commits.

With a clean worktree and current approval, integrate without an automatic
commit, squash, rebase, or merge commit:

```sh
wt -C <worktree> merge <target-branch> --no-commit --no-rebase --no-remove
```

This requires fast-forward integration; if the target moved, re-evaluate
before retrying. Retain worktrees on conflict or failed checks. After successful
integration, remove only the clean worktree created for this run with
`wt remove <group-branch> --foreground`, subject to project authorization.
Never force removal, push, or bypass hooks. A project rule that needs human
approval blocks the operation rather than being waived by this skill.

Re-read each task's `sourcePath` and exact line through the adapter before
changing its checkbox. Refresh on drift. Mark only verified, approved,
integrated work complete; preserve other content and refresh apply progress.
A checkbox is not a review verdict.

### 5. Run the final audit

Spawn a fresh read-only auditor sub-agent with
`../../references/final-audit.md`, the proposal, specs, optional design,
task groups, project standards, and implementation evidence. It audits the
whole delivered change, not builder reports. For pure refactors it checks
preserved behavior.

CRITICAL findings and applicable `Not verified` checks block done. Return
each blocker to a fresh builder and reviewer loop with the same **3-cycle
cap** for its audit-fix attempt. Count audit-fix cycles per affected group
across repeated audits; do not reset that budget within this run. Do not fix
inline or silently omit findings. Reopen affected tasks when work remains. Keep one commit per repaired group
by amending only an unpublished commit created by this run when safe; if
that cannot be done safely, report the blocker rather than rewrite user
history. Re-run a fresh final audit after repairs. WARNING and SUGGESTION
findings are reported only.

When every group is complete and the audit has no blockers, read
`roadmap_entry` from `.change.yaml`. Resolve the roadmap with `plan-cli list`
and run `plan-cli set-status <roadmap-location> --entry <id> --status done`.
Otherwise leave the entry unfinished. Never treat blocked or skipped work
as complete.

## Output

Return a final report with completed groups and commits, reviewer verdicts,
blocked groups and reasons, dependents skipped in this run, test and runtime
evidence, final audit findings, and what stays unresolved. Name retained
worktrees and suggested follow-up. Do not save a review log or blocked state.

## Guardrails

- Builder and reviewer always run in fresh sub-agents, never inline.
- Reviewer-only judgment is essential. Passing tests alone are not approval.
- No group advances with missing or failing tests, a missing Definition of
  Done check, or scope beyond its task group.
- Apply code-quality and reuse guidance in both builder and reviewer contexts.
- Preserve existing behavior unless the artifacts require a change. Never
  invent requirements, narrow behavior to pass, or discard unrequested work.
- Parallel work requires isolated worktrees and disjoint files. Integration
  is serial and requires current approval and checks.
- Exhausting the cycle budget is not success. Report blockers and dependent
  skips; the next run retries them without persistent blocked status.
- Per-group review cannot replace the fresh final audit.
