---
name: spec-first
description: Investigate, spec, checkpoint, then implement. No code without a confirmed plan and a clean baseline.
invocable: true
---

# Spec-First Workflow

You are about to implement a task. **Before writing any code**, you MUST complete all steps below in order. Do not skip steps — even if the task seems simple. Especially if the task seems simple.

---

## Step 1: Investigate Before Speccing

Do NOT write a spec from assumptions. Read first.

- [ ] **Read the affected code** — understand what exists before proposing changes
- [ ] **Read existing tests** — know what's already covered and what the expected behavior is
- [ ] **Check dependencies** — what other files import/use the code you'll touch?
- [ ] **Reproduce the issue** (if it's a bug) — confirm you understand what's actually broken
- [ ] **Check for similar patterns** — does the same issue/pattern exist elsewhere in the codebase? A fix in one place often means fixes needed in others
- [ ] **Verify tool/API assumptions** — if the task introduces a new library, framework, or external tool, verify its actual API before building a spec around it. Do not assume a function, parameter, or capability exists — check docs or source. A spec built on a wrong assumption about a tool will fail at implementation.
- [ ] **Map failure modes of external calls** — for each new external API call, pragma, syscall, or subprocess, answer: what happens on failure? Does it raise, return an error code, or fail silently? Silent failures are the most dangerous — they let the code "work" while the feature is actually broken. If a call can fail silently, the spec must include detection/logging for that case.
- [ ] **Audit configuration sources** — if the task introduces a new config file or tool with its own config (e.g., alembic.ini, .eslintrc), check whether it duplicates values already defined elsewhere in the codebase. Identify the single source of truth and plan to wire the new config to it, not copy-paste the value.
- [ ] **Enumerate the full route surface** (required when task changes auth, CORS, or any security boundary): List EVERY route the application exposes — including framework-generated routes (e.g., `/docs`, `/redoc`, `/openapi.json` for FastAPI; `/admin` for Django; `/_next` for Next.js). Produce this table in the spec:

  | Route | Source | Auth? | Justification |
  |-------|--------|-------|---------------|

  "Source" = your code, framework default, or middleware.
  "Auth?" = protected / intentionally open.
  Every "intentionally open" row needs a justification.
  Any route you cannot classify → add to the spec as a risk.
  This table is a required artifact — not producing it is a gate failure.
- [ ] **Learn the project's code style** — before writing any code, understand the conventions:
  - Naming convention (camelCase, snake_case, PascalCase)
  - Import style (relative/absolute, file extensions, barrel imports)
  - Test file location pattern (co-located, `__tests__/`, `.test.` vs `.spec.`)
  - Documentation style (JSDoc, docstrings, inline comments)
  - Commit message format (conventional commits, etc.)
  - Verification commands (what to run before done)
  - If the project has CLAUDE.md, .cursorrules, or similar project instructions — read them first

Only after investigation, proceed to Step 2.

If anything is unclear after investigation, ask the user before speccing. Do not guess.

---

## Step 2: Write the Spec

Write a spec in this exact format:

```
## Task Spec

**What**: [One sentence — what is being built or changed]

**Why**: [One sentence — what problem this solves]

**Files to touch**: [List the specific files you plan to modify or create]

**Acceptance criteria** (must be testable):
- [ ] [Criterion 1 — observable, verifiable behavior]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

**Decisions** (required if the task has design forks):
- [Decision 1]: [Options considered] → **[Chosen option]** — [Why]
- [Decision 2]: [Options considered] → **[Chosen option]** — [Why]

**Data structures** (required if the task creates new tables, APIs, configs, or schemas):
- Define every new data structure inline: columns/fields, types, constraints, defaults
- Do not leave a model as just a name — "add UserSignal table" is incomplete; specify the full shape

**Decomposition rationale**: [Why this many files/migrations/steps? Could they be combined? If splitting, what does each piece buy you?]

**Out of scope**: [What you will NOT do, even if it seems related]

**Risks / mitigations**:
- [Risk 1] → **Mitigation**: [Concrete action to prevent or handle it]
- [Risk 2] → **Mitigation**: [Concrete action, or "Accepted — [reason]" if no mitigation]
```

### Risk Checklist

When writing risks, always check these categories:
- **Configuration drift**: Does this change introduce a new source for a value that already exists elsewhere? (DB URLs, port numbers, feature flags). If so, wire the new config to the existing source of truth.
- **Tool global config**: If introducing a new tool, have you configured its global settings for your environment? (e.g., `render_as_batch=True` for Alembic+SQLite, strict mode for TypeScript)
- **Removed behavior**: If you're removing or replacing existing behavior (like `create_all()` → Alembic), what happens to code that called the old behavior? Will callers get helpful errors or silent breakage?
- **Silent failure modes**: For each new external call (API, pragma, subprocess, syscall), what happens on failure? If it returns a status instead of raising, the code must check that status. Silent failures are the most dangerous risk — the feature appears to work while doing nothing. Example: `PRAGMA journal_mode=WAL` returns the actual mode but never raises, so the caller must check the return value.

### Writing Good Acceptance Criteria

Each criterion must be something you can verify with a test or a concrete observation. Bad: "Code is clean." Good: "Function returns 404 when user ID doesn't exist."

**Name the system boundary.** Each criterion must specify *which module, function, or endpoint* is being tested. Bad: "WAL mode is active after engine creation." Good: "The engine from `src.db.session` returns `journal_mode=wal` on a new connection." A criterion that doesn't name the production code under test will produce tautological tests that test the tool, not your code.

**If a criterion can't be tested at runtime**, mark it `[review-gate]` and explain why. Don't force a behavioral test where one doesn't exist — a source-text or code-review check is honest; a fake behavioral test that only tests itself is worse than no test. Example: `[review-gate] create_engine uses connect_args={"timeout": 15}` — SQLAlchemy doesn't expose connect_args at runtime.

If you're fixing a bug, the first acceptance criterion should be: "A test exists that reproduces the original failure and now passes."

Cover **all user paths**, not just the happy path for current users:
- First-time setup (fresh clone, empty DB, no config)
- Existing user upgrade (data migration, backward compatibility)
- Future developer experience (clear error messages when prerequisites are missing)

If you removed or hollowed out a function that callers depend on, add a criterion for what those callers experience now.

---

## Step 3: Wait for Confirmation

After writing the spec, STOP. Ask the user:

> "Here's my spec for this task. Does this match what you want? Anything to add or remove before I start?"

**Do not write any implementation code until the user confirms.**

---

## Step 4: Checkpoint

Before writing any code, ensure you have a clean git baseline.

Check if there are uncommitted changes:
```bash
git status
```

If there are uncommitted changes, create a checkpoint:
```bash
git add -A && git commit -m "checkpoint: before [task description from spec]"
```

If the working tree is clean, note it and proceed.

**Why here:** AI coding is inherently unpredictable. You don't know what will change until it's done. The checkpoint gives you a known-good state to return to — regardless of what happens next.

---

## Step 5: Test Matrix

Before writing test code, decompose each AC into individual test cases. Produce this table:

| AC # | Method | Path / Input | Scenario | Expected |
|------|--------|-------------|----------|----------|

**Rules:**
- One row = one test function. No row may cover multiple methods or paths.
- If an AC mentions "all routes", "every endpoint", or any collective noun, enumerate each route explicitly. Run the app's route list (e.g., `[r.path for r in app.routes]`) to ensure completeness — do not enumerate from memory.
- The test count in Step 6 must exactly match the row count of this matrix. A mismatch means either the matrix is incomplete or tests are missing.
- If the matrix has more than ~20 rows, group by AC and consider whether the AC should be decomposed into sub-ACs in the spec.

This table is a required artifact — not producing it is a gate failure.

---

## Step 6: Write Acceptance Tests

Before writing any implementation code, turn each row of the test matrix into a test.

1. **Write one test per matrix row.** The test should verify the exact observable behavior described in the row.
2. **Run the tests.** They should all fail. If a test passes, either the criterion is already satisfied (remove it from the spec) or the test isn't actually testing what you think.
3. **If you need to modify an existing test**, document what you changed and why (this will be checked in the verify step).

This is the spec becoming executable. The acceptance criteria defined "done" in words — the tests define "done" in code.

---

## Step 7: Implement Until Tests Pass

Now write the implementation:

1. **Implement only what the spec says.** Nothing more.
2. **Run the acceptance tests after each meaningful change.** Stop when all pass.
3. **If you discover something the spec didn't cover**, STOP and ask — don't silently expand scope.
4. **Done = all acceptance tests pass**, not "it looks right."

---

## Step 8: Verify and Summarize

After implementation, run verification and output a structured summary:

```
## Done

**Checkpoint:** [commit hash or "working tree was clean"]
**Files changed**: [list, with type: new / modified / deleted]
**Acceptance criteria**:
- [x] [Criterion 1 — how verified]
- [x] [Criterion 2 — how verified]
**Tests:** [X passed, Y failed / ran full suite / no tests configured]
**Test files modified:** [Yes — explain what changed and why / No]
**Out of scope changes:** [None / list anything that drifted]
**Anything unexpected:** [note anything discovered during implementation]
```

If any acceptance criterion is NOT met, do not present the work as complete. Fix it or ask the user how to proceed.

---

## When Things Go Wrong

If implementation hits a wall — tests won't pass, the approach keeps failing, or unexpected complexity emerges — **don't keep patching the code. Go back to the spec.**

The spec may have been wrong from the start. Neither the human nor the AI always gets the spec right on the first try. That's expected. What matters is recognizing when the problem is the spec, not the implementation.

**The decision tree:**

1. **Roll back** to the checkpoint from Step 4.
2. **Ask: is the spec or the test matrix the problem?**
   - Did investigation miss something? (A dependency, an edge case, an architectural constraint)
   - Are the acceptance criteria testing the wrong behavior?
   - Is the approach fundamentally wrong, not just the implementation?
3. **If yes → revise the spec** (go back to Step 2), get user confirmation again (Step 3), then re-implement from the clean baseline.
4. **If no → try a different implementation approach** from the same checkpoint. But if two different approaches both fail, the spec is almost certainly the problem.

Fixing a wrong spec early costs minutes. Patching code built on a wrong spec costs hours — and the patches make the code harder to understand, not easier.

---

## Why Every Step Matters

| Step | What it prevents |
|------|-----------------|
| Investigate | Speccing from assumptions instead of reality (includes verifying tool APIs actually work the way you think) |
| Spec | AI solving a different problem than the one you meant — decisions, data shapes, and risk mitigations force precision |
| Confirm | Wasted work on the wrong approach |
| Checkpoint | Losing your current working state to an unpredictable change |
| Test matrix | One AC silently covering 11 behaviors but only testing 4 — the matrix forces enumeration before code |
| Acceptance tests | AI defining "done" by how the code looks instead of what it does |
| Implement until pass | Scope creep — done means tests pass, not "it looks right" |
| Verify | "It's done" when it's actually broken |
