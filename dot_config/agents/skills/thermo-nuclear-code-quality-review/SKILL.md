---
name: thermo-nuclear-code-quality-review
description: Multi-phase verification cycle — automated checks, quality review, fix, simplify, re-verify. No presenting until everything passes.
invocable: true
source: https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md
---

# Verify Before Presenting

You just finished writing or modifying code. Before presenting the result to the user, complete the full verification cycle below. This is a multi-phase process: automated checks → quality review → fix → simplify → re-verify. Do not skip phases. Do not present code until all phases pass.

**Core principle:** Two passes with refinement in between catches what a single pass misses.

---

## Phase 1: Automated Verification

### Step 1: Run Automated Checks

Run every automated tool the project has. Fix failures before proceeding.

**Required (run all that apply):**

- [ ] **Tests** — Run the FULL test suite, not just tests for changed files. Report pass/fail count.
- [ ] **Type checker** — If the project uses one (TypeScript `tsc`, Python `mypy`, etc.), run it. Fix all type errors you introduced.
- [ ] **Linter** — Run the project's linter (`eslint`, `ruff`, `clippy`, etc.). Fix all violations you introduced.
- [ ] **Formatter** — Run the project's formatter (`prettier`, `black`, `rustfmt`, etc.). Apply formatting fixes.
- [ ] **Build** — If the project has a build step, run it. Confirm it succeeds.

**If any check fails:**
1. Fix the issue
2. Re-run ALL checks (not just the one that failed — your fix may have introduced new problems)
3. Repeat until all checks pass

**If the project has no automated checks configured**, note it explicitly:
> "No automated checks configured for this project. Recommend adding at minimum: [suggest appropriate tools for the language/framework]."

### Step 2: Test Integrity Check

This is the one self-review that earns its place — because it targets a blind spot that automated tools cannot catch. If you modified the tests themselves, "all tests pass" means nothing.

**Check each item:**

- [ ] Did I **delete or comment out** any test cases?
- [ ] Did I **loosen any assertions**? (e.g., `toEqual` → `toBeTruthy`, `===` → `!= null`, specific error message → generic catch)
- [ ] Did I **wrap any tests** in `skip` / `xit` / `xtest` / `@pytest.mark.skip`?
- [ ] Did I **add mocks** that bypass the actual logic being tested? (A test that mocks everything it calls is testing the mocks, not the code.)
- [ ] Did I **only add happy-path tests** without edge cases?
- [ ] Did I **change expected values** to match my output instead of fixing my code to match the expected values?

**If you touched ANY test file**, you MUST provide:

```
## Test Changes

**File:** [path to test file]
**What changed:** [exact description of the change]
**Why:** [specific reason the change was necessary]
**Original assertion:** [what it was before]
**New assertion:** [what it is now]
```

If the reason is "my code produces a different output" — that's a red flag. The test may have been correct and your code may be wrong. State this explicitly and let the user decide.

**If you did NOT touch any test files**, state: "No test files modified."

**Gate:** All automated checks pass. No test integrity issues unresolved. Proceed to Phase 2.

---

## Phase 2: Quality Review & Fix

### Step 3: Code Quality Review

Review your own changes against these specific criteria. This is not "does it look right" — check each item concretely.

**Correctness:**
- [ ] Does the implementation match every acceptance criterion from the spec?
- [ ] **Input domain analysis** (required artifact — not producing it is a gate failure): For each new input the code reads (env var, config value, user input, API parameter, file content), produce this table:

  | Input | Source | Unset / missing | Empty `""` | Whitespace `"  "` | Valid | Malformed / unexpected |
  |-------|--------|----------------|-----------|-------------------|-------|----------------------|

  Each cell = what the code does (returns X, raises Y, treats as Z).
  Empty cells are not allowed — if a category "can't happen", state why.

  Common traps by source type:
  - **Env vars**: unset vs `""` vs whitespace vs trailing `\n` (from .env files)
  - **API params**: missing vs null vs empty string vs wrong type
  - **File paths**: missing vs empty file vs permission error
  - **DB values**: NULL vs empty string vs default value

  If the table reveals an unhandled category, fix it before proceeding.

- [ ] Are concurrency edge cases handled? (race conditions, concurrent access, shared mutable state)
- [ ] Are error paths tested, not just happy paths?
- [ ] **Failure mode audit**: For each new external call (API, pragma, subprocess, DB query), list what happens on failure. If the call can fail silently (returns status instead of raising), verify the code checks the return value. Do not check this box without listing the calls and their failure modes explicitly.

**Maintainability:**
- [ ] Functions have single responsibility
- [ ] No deep nesting or complex conditionals (max 2-3 levels)
- [ ] Variable and function names clearly describe their purpose
- [ ] No magic numbers or hardcoded strings — extract to named constants

**Code Style Compliance:**
- [ ] Naming convention matches the project
- [ ] Import style matches existing patterns
- [ ] Test files are in the expected location
- [ ] Documentation style matches project convention

**Scope Discipline:**
- [ ] Every changed file traces back to the spec
- [ ] No "while I'm here" improvements outside the spec
- [ ] No deleted code/comments/tests that weren't in scope

### Step 4: Fix Issues Found

If Step 3 identified any issues:

1. Fix them — prioritize: correctness first, then maintainability, then style
2. Re-run ALL automated checks from Step 1 (your fixes may introduce new problems)
3. Re-check test integrity (Step 2) if you modified tests during fixes
4. Repeat until all checks pass and all quality criteria are met

If you can't fix an issue without expanding scope, flag it for the user's decision — don't silently expand.

**Track what you fixed:**
```
## Quality Fixes Applied

- [Issue]: [What was wrong] → [What you changed]
- [Issue]: [What was wrong] → [What you changed]
```

**Gate:** All quality criteria met. All automated checks still pass. Proceed to Phase 3.

---

## Phase 3: Simplification

### Step 5: Simplification Pass

Review your changes with fresh eyes. The goal is clarity and maintainability — not cleverness.

**Check for:**
- [ ] Unnecessary complexity or nesting that can be flattened
- [ ] Redundant code that can be consolidated
- [ ] Overly verbose code that can be clarified (but don't sacrifice readability for brevity)
- [ ] Inconsistency with surrounding code patterns
- [ ] Abstractions that aren't earning their weight (one-use helpers, premature generalization)

**Constraints:**
- Preserve ALL functionality — simplification must not change behavior
- Prefer clarity over cleverness
- Don't refactor code outside the spec scope
- If in doubt, leave it as-is

### Step 6: Re-run Automated Checks

After simplification, run all automated checks again:

- [ ] Tests pass
- [ ] Type checker passes
- [ ] Linter passes
- [ ] Build succeeds

If anything broke, fix it. Simplification that breaks things isn't simplification.

**Gate:** All checks pass after simplification. Proceed to Phase 4.

---

## Phase 4: Final Verification & Summary

### Step 7: Git Sync Check

If the project has a remote repository:

```bash
git fetch origin
git status -uno
```

If behind remote, note it in the summary. The user should decide whether to rebase/merge before committing.

### Step 8: Change Summary

Output a structured summary the user can scan in 30 seconds. This is review material for the human — not a self-assessment.

```
## Change Summary

**Checkpoint:** [commit hash from before implementation, or "N/A"]

**Files changed:**
- `path/to/file.ts` — [new / modified / deleted] — [one-line description]
- `path/to/file.ts` — [new / modified / deleted] — [one-line description]

**Spec alignment:**
- In scope: [list changes that match the approved spec]
- Out of scope: [list any changes outside the spec, with justification — or "None"]

**Deletions** (code, comments, test cases, files):
- [List everything deleted — or "None"]

**Automated checks:**
- Tests: [X passed, Y failed, Z skipped]
- Type checker: [pass / fail / N/A]
- Linter: [pass / X warnings / N/A]
- Build: [pass / fail / N/A]

**Test files modified:** [Yes — see Test Changes above / No]

**Quality issues found and fixed:**
- [List issues found in Phase 2 and how they were fixed — or "None"]

**Simplifications applied:**
- [List simplifications made in Phase 3 — or "None"]

**Remote status:** [Up-to-date / Behind by N commits / No remote]
```

### Step 9: Self-Assessment Gate

Before presenting, answer honestly:

1. **Do all automated checks pass?** If no → go back to Phase 1.
2. **Did I weaken any tests?** If yes and can't justify → fix the code, not the tests.
3. **Are there out-of-scope changes?** If yes → remove them or flag explicitly for user decision.
4. **Does every file change trace back to the spec?** If no → explain why or remove the change.
5. **Did I skip the simplification pass?** If yes → go back to Phase 3.
6. **Are there known issues I'm hoping the user won't notice?** If yes → fix them or disclose them.

If any answer is wrong, fix it before presenting. Do not present work with known issues and hope the user won't notice.

---

## The Cycle

```
Phase 1: Automated Verification
  ├─ Run checks (tests, types, lint, format, build)
  └─ Test integrity check
       ↓
Phase 2: Quality Review & Fix
  ├─ Review against quality criteria
  ├─ (Optional) External reviewer dispatch
  ├─ Fix issues found
  └─ Re-run Phase 1 checks
       ↓
Phase 3: Simplification
  ├─ Simplify for clarity
  └─ Re-run Phase 1 checks
       ↓
Phase 4: Final Verification & Summary
  ├─ Git sync check
  ├─ (Optional) Final external review
  ├─ Structured change summary
  └─ Self-assessment gate
       ↓
  [Present to user]
```

If Phase 4 gate fails → loop back to the appropriate phase.

---

## Why This Structure

| Phase | What it catches | Why AI can't skip it |
|-------|----------------|---------------------|
| Automated checks | Syntax errors, type errors, lint violations, test failures | Machines give deterministic answers — no judgment needed |
| Test integrity | AI weakening tests to make code "pass" | The one blind spot automated tools can't see |
| Quality review & fix | Correctness gaps, style violations, scope creep | Structured criteria catch what "looks fine" misses |
| Simplification | Unnecessary complexity, inconsistency, premature abstraction | Fresh-eyes pass after fixing catches what implementation missed |
| Re-verification | Regressions from fixes and simplification | Every code change needs re-verification |
| Change summary | Scope creep, silent deletions, spec drift | Structures the human's review — saves 20 min of "what did it change?" |
| Self-assessment gate | Known issues being silently shipped | Forces honesty before presentation |
