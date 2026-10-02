---
name: visual-review
description: Render a plan directory as one self-contained HTML page so the flow, steps, decisions, risks, and status are reviewable at a glance. Trigger on "visual-review", "show the plan visually", "visual plan review", "review the plan visually". Reads PRD.md, SPEC.md, and the step files; writes a single offline HTML page into the plan dir; read-only on plan files.
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
- The status badge class comes from each step file's `Status` field, never from the PRD's Steps table or from guesswork.
- Copy the PRD's `Visualize` section, preserving ASCII diagrams in `<pre>` blocks. A linear plan can still have useful system or behavior diagrams. Do not add a step dependency graph if the PRD does not contain one.

## Visualize

Use ASCII diagrams liberally when the plan files contain them. Keep their
content and spacing unchanged. Do not invent diagrams or add this example
to the generated page unless it is part of the plan files.

```text
+------------------------------------------+
|     Use ASCII diagrams liberally         |
+------------------------------------------+
|                                          |
|   [State A] -------> [State B]           |
|       |                                  |
|       v                                  |
|   [State C]                              |
|                                          |
|   System diagrams, state machines,       |
|   data flows, architecture sketches,     |
|   dependency graphs, comparison tables   |
|                                          |
+------------------------------------------+
```

Draw with plain ASCII only: borders `+ - |`, arrows `--> <-- ^ v`, and
markers `* x`. Keep every diagram character ASCII. Unicode diagram glyphs
can have different widths across terminals, fonts, and locales. This can
move box borders and table columns out of alignment. In the HTML page,
use `<pre>` blocks to preserve diagram spacing and escape HTML characters
without changing the displayed text.

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
has no populated PRD Steps table or no SPEC (check via `plan-cli read`).
Ask the user to update an older plan through `spec` and `plan`; do not
change its files or guess missing content.

### 2. Read the inputs (read-only)
Run `plan-cli read <location> PRD.md` for the Steps table, Visualize section,
key decisions, and risks. Read each step file named in the table for its
card and status badge. Read `SPEC.md` for requirements and scenarios, or
preserved behavior for a pure refactor. Report any conflicts between these
files; do not invent or silently change content.

### 3. Generate the page
Fill `assets/viewer-template.html` per its contract comments: one overview row per PRD Steps row, one card per step file with its Status badge, and PRD Visualize content, decisions, and risks verbatim. Include SPEC requirements and scenarios verbatim, with their IDs (or preserved behavior for a pure refactor). Escape HTML special characters in all copied text, including diagrams, while keeping the displayed text unchanged. Embed each step's Implementation-chunks section VERBATIM in the card's `<script type="text/markdown">` block (code blocks included); never condense, truncate, or summarize chunk text. A step with a Chunks table renders that table instead. Write the result via `plan-cli write <location> visual-review.html`.

### 4. Open
Run `open "$(plan-cli path <location>)"/visual-review.html` and report the path. Do not modify the page further unless asked; regeneration goes through this procedure again.

## Verification

Before reporting done, confirm:
- [ ] Exactly one file was written; the plan directory is otherwise untouched.
- [ ] `rg -n "https?://|<script src" "$(plan-cli path <location>)"/visual-review.html` returns nothing.
- [ ] Every step in the PRD's Steps table appears as an overview row and a step card, with a badge matching that step file's Status.
- [ ] Visualize content matches PRD.md; ASCII diagrams keep their spacing and characters.
- [ ] Requirements and scenarios (or preserved behavior) match SPEC.md, with no missing IDs.
- [ ] Key decisions and risks match PRD.md verbatim.

## References

- Page contract: `assets/viewer-template.html`
- Step format: `~/.agents/skills/plan/SKILL.md` and `~/.agents/skills/plan/assets/step-file.md`
- PRD template: `~/.agents/skills/spec/assets/prd-file.md`
- SPEC template: `~/.agents/skills/spec/assets/spec-file.md`
