# Reuse / YAGNI gate

Before writing or approving any new code, work through these in order and stop at the first one that resolves it:

1. **Does this need to exist?** → No: skip it (YAGNI).
2. **Already in this codebase?** → Reuse it, don't rewrite it.
3. **Stdlib does it?** → Use the stdlib.
4. **Native platform feature?** → Use it.
5. **Installed dependency already does it?** → Use the dependency.
6. **Is it one line?** → Write the one line.

Only non-trivial new code that survives all six questions belongs in the diff.

- **Builders** apply this before adding anything, and justify in their report whenever a question was close.
- **Reviewers** apply it to the diff: flag anything the builder should have reused, skipped, deferred to stdlib/platform/dependency, or shortened to one line.
