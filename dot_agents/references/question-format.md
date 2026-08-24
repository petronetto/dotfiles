# Question format

How skills (`spec`, `plan`, `build`) present questions to the user and record the answers.

## Presenting

One question per message, numbered sequentially:

```
QX: <Question>
A) (Recommended) <option A> — <one-line reason>
B) <option B>
C) ...
```

- Exactly one `(Recommended)`, always option A.
- The user answers with a letter or free text; free text wins.
- If the codebase, PRD, or a prior answer settles it, read instead of asking.

## Recording

Append each entry to `<project-full-path>/.plans/<branch>/<task-name>/decisions.md` as soon as it is answered:

```markdown
## QX: <Question>
A) (Recommended) <option A>
B) <option B>
**Answer:** A — <answer as accepted, with any user refinement>
**Evidence:** CONTEXT.md › <topic or provenance row that informed this>
```

- Never rewrite an entry; a changed decision gets a new entry naming the one it supersedes.
- Continue numbering from the highest QX already in the file.
- The `**Evidence:**` line links the decision back to the research that
  informed it, so the PRD is traceable. Omit it only when the decision is a
  pure user preference with no supporting finding.
- When a decision is promoted to a standalone ADR (`ADR-NNN`), keep the
  `decisions.md` entry and add `**Promoted to:** ADR-NNN` instead of (or in
  addition to) the Evidence line.
