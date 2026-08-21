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
```

- Never rewrite an entry; a changed decision gets a new entry naming the one it supersedes.
- Continue numbering from the highest QX already in the file.
