# Writing comments

Comments preserve information that the code cannot clearly express. Each comment must earn its maintenance cost.

These rules apply to new and changed comments. Do not expand a task into an unrelated cleanup.

## Prefer clear code

**The default is no comment.** First improve names, structure, types, or control flow so that the code explains itself. Do not add unnecessary abstractions merely to remove a useful comment.

Do not add comments that:

- Translate the next line into prose, such as `Save the order` above `saveOrder(order)`.
- Label obvious sections, constructors, accessors, or test stages.
- Repeat information already clear from a name or type.
- Describe the editing process: `Added validation`, `Now uses the new client`, or `Removed the old fallback`.
- Preserve deleted code, obsolete alternatives, or a conversation with a previous author.

Version control records change history. Comments describe the current code. [1][2]

## Preserve information the code cannot express

A comment is useful when it explains a non-obvious constraint, reason, or consequence that a maintainer needs to change the code safely. Examples include:

- A business or protocol rule that explains an otherwise surprising decision.
- A security, concurrency, ordering, or performance constraint.
- A workaround for a verified external defect.
- Units, ownership, preconditions, or failure semantics that an interface's names and types cannot adequately express.

Required license notices, tool directives, and interface documentation remain valid. Do not generate boilerplate documentation that merely repeats the signature. A suppression directive should explain the specific reason for the exception when that reason is not evident. [1]

## Make each comment stand on its own

**A necessary comment must make sense beside the current code, without a diff, chat history, or knowledge of a removed implementation.** State the relevant constraint and why it matters. Use precise, present-tense language. [2]

For example:

```text
Bad:  Keep this because the old approach broke retries.
Good: Reuse the idempotency key on retries so a timeout cannot create a second charge.
```

Issue links are a valid exception to complete local context. A workaround or TODO may refer to a GitHub issue for evidence, discussion, or a removal condition. Still prefer a short local explanation of the problem and the condition for removing the workaround, followed by the link. Do not invent issue numbers or links.

Avoid vague statements such as `Handle edge cases`, `This is important`, or `Temporary fix`. A TODO must identify a concrete remaining action, not an unspecified intention to improve the code.

## Keep comments accurate

**Review nearby comments whenever behavior or structure changes.** Update or delete comments made false or irrelevant by the change. Remove a workaround comment when the workaround is removed.

Check factual claims against the current implementation or an authoritative source. Do not claim a guarantee the code does not provide. If a comment contradicts the code, resolve the discrepancy; do not assume either is correct without checking the requirement.

## Final review

Before keeping a comment, ask: **What necessary information would a maintainer lose without it, and is it still true?**

Remove additions that have no clear answer.

## Sources and rationale

These are project rules informed by established engineering guidance, not a claim that every team uses the same policy.

1. [Google C++ Style Guide: Comments](https://google.github.io/styleguide/cppguide.html#Comments): avoid stating the obvious; explain non-obvious decisions and document interface obligations.
2. [Software Engineering at Google: Documentation](https://abseil.io/resources/swe-book/html/ch10.html): write for the reader, distinguish interface documentation from implementation commentary, and maintain or remove obsolete documentation.
