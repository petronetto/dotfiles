# Question format

How skills (`spec`, `plan`, `build`) present questions to the user and record the answers.

## Presenting

One question per message, numbered sequentially:

```
<Brief Context of the Question>
QX: <Question>
A) (Recommended) <option A> — <one-line reason>
B) <option B>
C) ...
```

- Write in ASD-STE100 Simplified Technical English.
- Ensure that the questions and options are meaningful and not just filler. Review and refine the options before asking the user.
- Include exactly one `(Recommended)` option, and it must always be option A.
- If the harness provides a tool for asking questions, use it.
- When using a tool to ask questions, do not repeat sections. Use the tool appropriately and keep the output clean.
- The user may answer with a letter or free text; free text takes precedence.
- If a question can be answered by exploring the codebase, do that instead.

## Recording

Append each entry to `decisions.md` as soon as it is answered:

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
