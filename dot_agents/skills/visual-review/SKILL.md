---
name: visual-review
description: Render a plan directory as one self-contained HTML page so the flow, steps, decisions, risks, and status are reviewable at a glance. Trigger on "visual-review", "show the plan visually", "visual plan review", "review the plan visually". Reads FLOW.md, the step files, and PRD.md; writes a single offline HTML page into the plan dir; read-only on plan files.
argument-hint: "[task-name]"
---

# Visual review

Render a plan directory as one self-contained HTML page for plan approval.
The page mirrors the files; the files stay the source of truth. Zero
dependencies: no scripts, no libraries, no server, no network. Generation is
the agent filling the template contract; see ADR rationale in the plan's
`decisions.md` when present.

## Hard rules

- Write exactly one file: `visual-review.html` inside the plan directory. Never create, edit, or delete any plan file; the page mirrors them.
- The page is self-contained: inline CSS, one inline vanilla-JS chunk converter only, no external scripts, no network requests; it must open offline.
- Data comes only from the plan files. If a file does not say it, the page does not show it; files win over the page when they disagree, and a mismatch is reported, not papered over.
- Ask before overwriting an existing `visual-review.html` (`plan-cli read <location> visual-review.html` succeeding means it exists).
- Never commit the page.

## Gotchas

- Regenerating after plan changes is normal behavior, but the existing page is still overwritten only after asking.
- The status badge class comes from each step file's `Status` field, never from FLOW.md or from guesswork.
- A linear plan omits the whole graph section even though the template contains it; a branched plan must include it (same rule as FLOW.md).

## Plan CLI

- `plan-cli` below means `~/.agents/plan-adapters/plan`. Every plan-file
  operation goes through it, never through a hand-built path: `init
  <task-name>` (prints the task's `<location>`, idempotent), `read
  <location> <file>`, `write <location> <file>` and `append <location>
  <file>` (content on stdin, via heredoc), `list` (one `<location>` per
  line), `set-status <location> (--step <file> | --entry <id>) --status
  <status> [--reason <text>]` (the step's `Blocked` row moves in lockstep
  with `blocked`), and `path <location>` (the `<location>`'s
  on-disk directory).
- `PLAN_BACKEND` selects the backend (`disk` by default); its settings
  live in `~/.agents/plans.config.md`. Every `<location>` comes from
  `init` or `list` output.

## Procedure

### 1. Locate the plan directory
Run `plan-cli list` to enumerate the task directories. With a
`<task-name>` argument, pick the listed entry ending in `/<task-name>`;
without one, ask which listed task to render. Call the chosen entry
`<location>` for the rest of this run. Stop if the entry is missing or
holds neither `FLOW.md` nor a PRD Steps index (check via `plan-cli read`);
there is nothing to render.

### 2. Read the inputs (read-only)
Run `plan-cli read <location> FLOW.md` (flow table rows and the
branched-or-linear rule), then `plan-cli read` every step file it names
(cards and status badges), and `plan-cli read <location> PRD.md` (key
decisions and risks). When `FLOW.md` is absent (plans made before the flow format), derive the flow rows from `PRD.md`'s Steps index plus each step file, and state the fallback in the page footer. Nothing else is needed; do not invent sections.

### 3. Generate the page
Fill `assets/viewer-template.html` per its contract comments: one flow-table row per step, one step card per step file with its Status badge, the dependencies section only when dependencies branch, and PRD decisions and risks verbatim. Embed each step's Implementation-chunks section VERBATIM in the card's `<script type="text/markdown">` block (code blocks included); never condense, truncate, or summarize chunk text. A step with a Chunks table renders that table instead. Write the result via `plan-cli write <location> visual-review.html`.

### 4. Open
Run `open "$(plan-cli path <location>)"/visual-review.html` and report the path. Do not modify the page further unless asked; regeneration goes through this procedure again.

## Verification

Before reporting done, confirm:
- [ ] Exactly one file was written; the plan directory is otherwise untouched.
- [ ] `rg -n "https?://|<script src" "$(plan-cli path <location>)"/visual-review.html` returns nothing.
- [ ] Every step in FLOW.md appears as a flow-table row and a step card, with a badge matching that step file's Status.
- [ ] The graph section exists only when dependencies branch.
- [ ] Key decisions and risks match PRD.md verbatim.

## References

- Page contract: `assets/viewer-template.html`
- Input format (owned by `plan`): `~/.agents/skills/plan/SKILL.md`, templates `~/.agents/skills/plan/assets/flow-file.md` and `~/.agents/skills/plan/assets/step-file.md`
- PRD template (owned by `spec`): `~/.agents/skills/spec/assets/prd-file.md`
