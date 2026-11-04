# Final audit

Run this read-only audit after the task groups finish, including when apply
state is `all_done`. Completion claims and checkboxes are not implementation
evidence. Use `../plan-adapters/change-workflow.md` and the selected schema.
Do not implement tasks, change checkboxes or metadata, commit, or archive
inside the audit. Return findings to the calling build workflow's fix loop.

## Load evidence

Resolve the change and main-spec catalog with `plan-cli list`. Do not
initialize storage or switch backends on errors. Derive the apply view from
actual adapter reads. Read all available `contextFiles`, and aggregate tasks
and progress from every readable file matched by `apply.tracks`. Apply state
and instructions are context, not a verdict.

Load applicable engineering guidance from this reference directory:
`clean-code.md`, `code-quality.md`, `SOLID.md`, `writing-tests.md`, and
`writing-comments.md`. Limit checks to changed or directly affected code,
tests, and comments. Do not demand unrelated cleanup, abstractions, tests,
or comments without a concrete need.

## Report dimensions and evidence limits

Use three dimensions: **Completeness**, **Correctness**, and **Coherence**.
Each can contain **CRITICAL**, **WARNING**, and **SUGGESTION** findings.

- **Not applicable**: the schema does not define the check, or its artifact
  was intentionally skipped. Respect `skip_specs: true`, optional design,
  and schemas without task tracking. Do not invent optional artifacts.
- **Not verified**: an applicable check lacks usable evidence. Name the check
  and reason. Partial evidence is not a fully verified result.
- If only task evidence is available, verify task completion only. Mark other
  applicable checks, including Code Pattern Consistency, Not verified with
  the reason "Only task evidence available".
- Missing requirements affect Spec Coverage and Requirement Implementation
  Mapping. Missing scenarios affect Scenario Coverage. Missing usable design
  decisions affect Design Adherence. Continue other supported checks.

## Completeness

### Task Completion

If `taskTrackingConfigured` is false, report Not applicable. Otherwise use
aggregate tasks and progress, not a hard-coded artifact ID or filename.
Report complete versus total tasks. If `unavailableTrackingFiles` is nonempty,
mark this check Not verified and list every unavailable path and reason.
Continue with readable evidence without inferring overall completion.

If tracking is configured but tasks are empty, report Not verified with the
apply state's reason. Nonzero totals alone do not prove usable descriptions.
Add a CRITICAL finding for every incomplete task. If remaining exceeds listed
incomplete descriptions, report the undescribed checkboxes too. Recommend
completing the work, or correcting a checkbox after implementation is proved;
do not change it during the audit.

### Spec Coverage

Find spec artifacts by their schema output paths under `specs/`, not fixed
IDs. If absent or empty when applicable, mark Spec Coverage, Requirement
Implementation Mapping, and Scenario Coverage Not verified. For a pure
refactor, spec-dependent checks are Not applicable; audit the proposal's
preserved behavior and preservation checks instead.

Extract `### Requirement:` blocks and FROM:/TO: pairs. Their ADDED, MODIFIED,
REMOVED, or RENAMED section determines the check.

- **ADDED or MODIFIED**: find implementation evidence for the required
  behavior. Check the complete updated MODIFIED text, not the old baseline.
  If apparently absent, report CRITICAL: "Requirement not found: <name>",
  with a specific implementation recommendation.
- **REMOVED**: read the baseline body and scenarios from
  `<capability-path>/spec.md` in the configured main-spec catalog, preserving
  the delta's full capability path. Match normalized names, including near
  equivalents. Reason/Migration notes and the title alone are not a baseline.
  If already removed from the catalog, recover history in the repository that
  owns the catalog, following the shared reference's history procedure.
  Re-check unmatched history paths; the wrong path proves nothing.
  A title-only baseline is unusable. If no usable baseline exists, mark this
  entry's Spec Coverage Not verified and stop that check. Otherwise search
  for the actual baseline behavior. Planning or documentation matches do not
  count. Code serving only Migration or ADDED behavior is insufficient, but
  a shared path still delivering removed behavior does count. If it remains,
  report CRITICAL: "Removed requirement still implemented: <name>", with
  file/line ranges and a remedy consistent with Migration. Do not recommend
  restoring removed behavior or call its expected absence a missing feature.
- **RENAMED**: only names change. Check that TO preserves FROM's behavior;
  do not require code symbols or files to be renamed. If TO is also MODIFIED,
  check its updated text there instead of duplicating the check. Otherwise
  read the FROM baseline, or TO if FROM is absent because the catalog is
  already synced. Use body and scenarios, not just names. If the baseline is
  unavailable, mark this entry Not verified. If behavior is missing, report
  CRITICAL: "Renamed requirement not found: <TO name>" and recommend restoring
  the behavior. Apply the same preservation check to explicit scenario-name
  mappings within their parent requirement.

## Correctness

For readable removal/rename-only deltas, Requirement Implementation Mapping
and Scenario Coverage are Not applicable. Their baseline checks run under
Spec Coverage, and any Not verified result there remains. A spec with no
parseable requirements is unusable, not removal-only.

### Requirement Implementation Mapping

For each ADDED or MODIFIED requirement, record implementation file paths and
line ranges. Compare the code with its intent and limits. On divergence,
report WARNING: "Implementation may diverge from spec: <details>", with a
specific file/line recommendation. Report clearly missing behavior under
Completeness rather than duplicate it.

### Scenario Coverage

For each scenario under ADDED or MODIFIED, check its conditions in code and
tests that assert the observable application outcome. Mocked SDK returns,
DTO mechanics, configuration declarations, or source-text assertions alone
are not application behavior evidence. Reuse meaningful existing coverage;
one test can cover several scenarios. Check application-owned validation,
mapping, configuration effects, and integration contracts, not dependencies.

If apparently uncovered, report WARNING: "Scenario not covered: <name>".
Name the concrete failure and smallest useful test or implementation change.
State whether tests were inspected or executed. Never call inspection a
passing run. Do not check removed scenarios as behavior that should remain.

## Coherence

### Design Adherence

If the schema has no design artifact (ID `design` or output ending in
`design.md`), or it was deliberately skipped, report Not applicable.
Otherwise compare decisions in Decision, Approach, or Architecture sections
with implementation. A contradiction is WARNING: "Design decision not
followed: <decision>". Recommend a code fix or a separately authorized design
revision. An absent, empty, or unusable applicable design is Not verified.
Other usable artifacts still support Code Pattern Consistency.

### Code Pattern Consistency

If implementation changes cannot be identified, report Not verified and why.
Otherwise check focused responsibilities, clear names, error handling, small
interfaces, and justified dependencies against engineering guidance and valid
project patterns. Apply SOLID where useful, not as a demand for more layers.
Do not copy flawed patterns for consistency.

Check tests for distinct behavioral value, realistic flows, useful assertions,
and reliability. Flag implementation mirrors, dependency tests, and duplicate
coverage without a distinct risk. Multiple assertions can prove one behavior;
counts and coverage percentages alone do not prove quality.

Check changed and affected nearby comments for noise, change narration, stale
claims, obsolete workarounds, and references to deleted code. Preserve useful
issue-linked context. Do not demand comments where code is clear.

Tie every finding to a concrete risk with file/line evidence. Use SUGGESTION
for significant pattern deviations, WARNING for demonstrated material
maintenance or test-confidence risk. Do not duplicate missing behavior here.

### Unrequested work

Compare the delivered diff with the request, proposal goals and excluded work,
applicable specs, and task scope. Report work outside that scope as
`unrequested`; never delete it during the audit. Also classify behavioral gaps
as `missing`, `partial`, or `contradicts` where useful. Give evidence and a
specific recommendation. Unrequested work is WARNING unless it independently
meets a CRITICAL criterion or violates a controlling project boundary.

## Output and done gate

Return a Markdown report in the conversation, not a report file unless asked.
For each dimension, list checks that ran, evidence, and every Not verified
reason. Count only ADDED and MODIFIED requirements in implementation totals;
report removals, renames, and baseline limits separately. Exclude Not
applicable checks from missing-evidence counts. A dimension with only
inapplicable checks is Not applicable, not a pass.

Group findings by priority, with actionable advice and `file:line` references:

- **CRITICAL**: incomplete tasks, missing required behavior, removed behavior
  still present, lost renamed behavior, or a controlling boundary violation.
- **WARNING**: spec/design divergence, missing scenario coverage, unrequested
  work, or material maintenance or test-confidence risk.
- **SUGGESTION**: pattern inconsistencies or minor improvements.

CRITICAL findings and applicable Not verified checks block done and return
to the caller's fix loop. The audit stays read-only. WARNING and SUGGESTION
are reported only and do not block done. Include their counts even when
nonblocking. Never narrow requirements or relabel missing evidence to pass.

If blocked, name every blocker and unresolved check. Otherwise state that
no blocking findings remain, with warning and suggestion counts. Distinguish
inference from runtime proof. Prefer the lower severity when evidence does
not justify a stronger claim, but never treat absent evidence as success.
Do not claim archive completion or invent an archive command.
