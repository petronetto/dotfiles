# Change storage adapter

This reference replaces storage and CLI discovery for the five change skills.
It does not replace their workflow. Keep `proposal.md`, `design.md`,
`tasks.md`, and `specs/<capability-path>/spec.md`, with the bundled schema's
original sections, delta operations, and checkbox tracking.

## Commands and locations

Set `PLAN_CLI="$HOME/.agents/plan-adapters/plan"`. The shorthand `plan-cli`
in a skill means this executable. Run it from the target project's working
directory, with all arguments quoted:

```sh
"$PLAN_CLI" list
location="$("$PLAN_CLI" init add-user-auth)"
"$PLAN_CLI" files "$location"
"$PLAN_CLI" read "$location" proposal.md
"$PLAN_CLI" write "$location" specs/identity/user-auth/spec.md <<'EOF'
<complete artifact>
EOF
```

Use the adapter for every artifact read, write, append, and inventory. A
filename is relative to the selected location, including nested capability
paths. Never construct an absolute storage path or use `path` to bypass
artifact operations. `files` returns sorted relative filenames and does
not write. The adapter rejects traversal and symlink artifact paths.

Preserve `PLAN_BACKEND` (default `disk`), `PLAN_CONFIG`, and any backend
override throughout the operation. Read `~/.agents/plans.config.md`, or
`$PLAN_CONFIG` when set, for storage settings. The adapter resolves roots,
vaults, folders, and `<repo-name>` substitutions. No workflow creates its
own storage root or changes configuration. A backend error is not an empty
inventory; stop and report it without switching backends.

Get every location from `list` or `init`. Existing work is selected by its
name, the final component of a listed location. `init` is write-capable:
use it only for authorized task creation, never during verification or
read-only exploration. If a name already exists, ask before resuming or
creating another task. An empty list needs no installation or setup step.

## Change scaffold and schema

For authorized creation, call `init <name>`, then write `.change.yaml`
through the adapter before authoring artifacts:

```yaml
schema: spec-driven
skip_specs: false
```

Do not overwrite existing metadata. `skip_specs: true` is only for changes
without spec-level behavior changes, such as pure refactors or tooling.
Do not invent a requirement to avoid this option. A change may record
`skipped: [design]` only after its schema's conditional design instruction
was evaluated and found inapplicable. Do not use this to skip required work.

The default schema and all templates are bundled under
`schemas/spec-driven/` beside this reference. Read `schema.yaml` and the
artifact's template before drafting. The schema supplies artifact IDs,
outputs, `requires`, `instruction`, and `apply` rules. A user-requested
custom schema must be present under `~/.agents/plan-adapters/schemas/`;
inspect those files to list workflows. Never silently fall back when a
requested schema is absent or invalid. Existing change metadata selects
its schema. A location without `.change.yaml` is not a change managed by
these skills: do not convert another skill's plan without asking.

## Project context and durable specifications

The reserved task name `specs` is the main-spec catalog inside the configured
storage root. Discover it with `list`; its baseline files are
`<capability-path>/spec.md`. A change keeps its deltas at
`specs/<capability-path>/spec.md` inside its own location. Do not confuse
these two scopes or treat another change's delta as a baseline.

List catalog files through `files <specs-location>` and read each relevant
baseline through `read <specs-location> <capability-path>/spec.md`, including
all scenarios. If there is no catalog, report no existing specs; do not
create one during discovery. Creation of baseline specs requires a separate
explicit request, not a planning or implementation side effect.

The catalog may contain `config.yaml` with `context`, artifact-keyed
`rules`, optional `operationGuidance` for apply, and a `schema` default.
Read it through the adapter when present;
use `spec-driven` otherwise. Treat context and rules as constraints, not
permission to change workflow or claim completion. Do not copy instruction
blocks into artifacts. Project instructions also apply. For proposal
context, use only a string no larger than 51,200 UTF-8 bytes; if the config
or field is invalid or unreadable, continue without that optional context,
as the proposal workflow permits. Storage/configuration errors from the
adapter itself still stop the operation.

## Status (derived from adapter reads, not a new CLI command)

Where a skill calls for status, run `files <location>`, read `.change.yaml`,
and inspect the selected schema. Build the following working view from
actual results. Do not claim the CLI returned JSON it does not produce:

- `schemaName`, `applyRequires`: schema name and `apply.requires`.
- `changeRoot`: the opaque location returned by the adapter.
- `planningHome`: selected backend and optional main-spec catalog location.
- `artifactPaths.<id>.outputPath`: schema `generates`, relative to the change.
- `artifactPaths.<id>.existingOutputPaths`: matching relative paths from
  `files`. Resolve all later operations as `<location>` plus that relative
  filename through the adapter, not filesystem concatenation.
- `artifacts`: schema order, with each artifact's `requires` and state.
  A matching file means `done`, even for a partially written multi-file
  artifact. Missing output with satisfied dependencies means `ready`;
  otherwise `blocked`. `skip_specs: true` makes specs `skipped`; declared
  conditional skips also count as satisfied and must have no output.
- `isPlanningComplete`: all artifacts are `done` or intentionally `skipped`.
  This describes file presence, not approval, content validity, or task
  completion. Always check partial multi-file artifacts separately.
- `actionContext`: the selected project, storage scope, and user-authorized
  edits. A vault location need not be in the target code repository.

When selection needs recency, use the adapter inventories and a read-only
`path <location>` followed by filesystem modification-time inspection only.
Do not read or write artifacts through that filesystem path. If recency is
unavailable, say so and ask instead of claiming list order is recency.
Exclude the `specs` catalog and unrelated plans from active changes. Include
changes without tasks when selecting planning or verification work.

## Instructions and apply state

Where a skill requests artifact instructions, read the selected artifact's
`instruction` and template from the bundled schema, the actual dependency
files through the adapter, and applicable context/rules. These replace the
CLI instruction response, without changing its meaning:

- `template`, `instruction`, `dependencies`, `context`, and `rules` come
  from those files. Mark skipped dependencies as skipped; do not read
  nonexistent outputs for them.
- `resolvedOutputPath` is the schema's relative `generates` path or glob.
  For a glob, choose the concrete capability path using the proposal.
  Use only checked relative filenames inside the selected location. The
  adapter enforces traversal and symlink checks on each read/write.
- A skipped artifact must not be created. Record a conditional skip in
  `.change.yaml`, preserving its other fields, and report the reason.
- After writing, re-read the artifact with the adapter and refresh status.
  For existing files, re-read immediately before updating and preserve
  unrelated content. Stop if a concurrent edit needs reconciliation.

For apply instructions, read every existing artifact output as `contextFiles`.
Read all files matched by `apply.tracks` and aggregate task progress:

- Track checkbox list lines wherever they appear, including fenced code,
  comments, and indented blocks. Accept `-`, `*`, `+`, or ordered list markers
  of one to nine digits followed by `.` or `)`, with leading whitespace.
  A checkbox has at most one non-whitespace character inside it. Only `x`
  (case-insensitive, ignoring whitespace) is done; empty boxes and every
  other single-character marker are unfinished. Multi-character labels and
  Markdown links are not tasks. A nonempty box immediately followed by `(`
  or `[` is a link, not a task; whitespace-only boxes still count there.
  Keep blank descriptions in counts. Do not drop a task because it is in
  a documented example; a false-positive count is safer than lost work.
- Each task has its description, relative `sourcePath`, and 1-based line.
  Preserve blank-description checkboxes in counts and report that gap.
  Re-check the exact line and description before editing its checkbox.
- `taskTrackingConfigured` is whether the schema defines `apply.tracks`.
  Count `total`, `complete`, and `remaining` across all tracking files.
  Record unreadable matching tracking files and reasons as
  `unavailableTrackingFiles`; partial evidence is not completion. A missing
  tracking output is a separate blocker, not an unreadable file.
- Apply is `blocked` if an artifact named directly in `apply.requires` is
  missing (excluding declared skips), or tracking is configured but has
  no matching file or no readable task descriptions. Report the direct
  `missingArtifacts` and also list missing transitive prerequisites as
  context. Do not add a new transitive gate to apply: unlike proposal
  generation, apply tests the schema's direct required set.
- Apply is `all_done` only when that required set is present, tracking has
  at least one task, all tracked tasks are complete, and no tracking file
  was unreadable. Otherwise it is `ready` with the schema's apply
  instruction, unless one of the blockers above applies. Report partial
  unreadable evidence even when work on readable tasks can proceed.
  Schemas without tracking are `ready`, never implicitly complete.

These are working views calculated by the agent from adapter data, not
additional `plan` subcommands. Do not call unsupported `status`,
`instructions`, `archive`, `show`, or JSON-list commands.

## History and limits

For removal or rename verification, use the catalog baseline. If it has
already changed, resolve the catalog's filesystem directory with `path`
and inspect history in the git repository that owns that directory. Use
the actual relative path of `<capability-path>/spec.md` in that repository,
not a path in the implementation repository. History access is read-only.
An unmatched history path is not proof that a baseline never existed.
If usable baseline history is unavailable, mark that check not verified.

The five skills do not implement archive or spec synchronization. Preserve
such follow-up in reports or untracked workflow bullets; ask the user to
use their own archival process after verification. Do not invent a command
or delete/move files to simulate it. Verification never implements, changes
task checkboxes, or changes metadata.
