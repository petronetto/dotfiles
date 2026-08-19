---
name: checkpoint
description: Git commit before any AI operation. Known-good baseline, not optional insurance.
invocable: true
---

# Checkpoint

Before executing any task that modifies code, you MUST create a git checkpoint. This is not optional. This is not only for "dangerous" operations.

AI coding is inherently unpredictable. You do not know what you will change until you're done. The checkpoint gives you and the user a known-good baseline to diff against and roll back to.

---

## When to Checkpoint

**Always.** Before any operation that creates, modifies, or deletes files.

The question is not "is this operation risky enough to checkpoint?" The question is "why would I ever skip it?"

---

## The Process

### Step 1: Check for uncommitted changes

```bash
git status
```

### Step 2: Checkpoint or skip

**If the working tree is clean** — no uncommitted changes — skip the commit. You already have a clean baseline (the current HEAD). Tell the user:

> "Working tree clean — current HEAD `[hash]` is our baseline. Starting [task description]."

**If there are uncommitted changes**, commit them:

```bash
git add . && git commit -m "checkpoint: before [brief description of upcoming task]"
```

(Ensure your `.gitignore` covers secrets and large files before checkpointing.)

Tell the user:

> "Checkpoint created: `[commit hash]`. Starting [task description]."

### Step 3: Proceed with the task

Now execute the work.

### Step 4: If something goes wrong

If tests fail, code breaks, or the result isn't what was expected, tell the user:

> "Something isn't right after this change. We have checkpoint `[hash]` — would you like to roll back with `git reset --hard [hash]`?"

**Never roll back without asking.** The checkpoint is a safety net, not an auto-revert.

---

## After the Task: Cleanup

Checkpoint commits are interim artifacts. When the task is complete and verified:

- **Squash** checkpoint commits into the final commit: `git rebase -i` to combine the checkpoint + implementation into one clean commit
- Or leave them if you prefer a detailed history — that's a personal choice

A messy interim history you can clean up later is infinitely better than lost work you can't recover.

---

## Integration with Other Skills

If you're in the `spec`/`plan`/`build` pipeline, the checkpoint happens after `spec` approval and before `build`. You don't need to run this skill separately — it's built in.

If you're working outside the pipeline, run this checkpoint manually before starting any code changes.

---

## Why This Matters

AI coding tools sometimes:
- Delete code comments silently ("unnecessary")
- Remove test cases to make code "pass"
- Modify files outside the requested scope
- Make sweeping changes that are hard to untangle

Without a checkpoint, you're comparing the result against your *memory* of what the code looked like. With a checkpoint, you're comparing against a git diff — exact, complete, and reliable.

A checkpoint takes 2 seconds. Reconstructing lost work takes hours.
