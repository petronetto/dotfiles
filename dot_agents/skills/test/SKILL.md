---
name: test
description: Prove behavior with tests, not by reading code. Use when implementing any logic, fixing any bug, or changing any behavior. Trigger on "test", "tdd", "prove it works", "regression test". Stack-agnostic; discovers the project's own test commands.
---

# Test

Tests are proof; "seems right" is not done. For a change, write a failing test first, then the minimum code to make it pass, then refactor keeping it green. For a bug, reproduce it in a test before touching a fix. A codebase with good tests is the thing that makes `build` and `build-auto` trustworthy.

## When to use

- Implementing new logic or behavior, or changing existing behavior.
- Fixing a bug (use the Prove-It pattern).
- Adding edge-case or error-path handling.

**When NOT to use:** pure config, docs, or static content with no behavioral effect.

## Discover the stack first

The cycle is universal; the commands are not. Before the first test, find out how *this* project tests and use its commands for every cycle step:
- Build/test tool and wrapper (prefer a checked-in wrapper like `./gradlew`, `make test`, or a repo script over a global tool).
- How to run one focused test vs the full suite.
- Where tests live, how test files are named, the conventions neighboring tests follow.
- The commands that actually gate merges (README, CONTRIBUTING, CI).

Never assume a default like `npm test`. Read the `Commands` section of `.plans/.../PRD.md` when it exists.

## The cycle

```
RED: write a test that fails  ->  GREEN: minimum code to make it pass
   ->  REFACTOR: clean up while it stays green  ->  repeat
```

A test that passes immediately proves nothing.

### Bug fixes: Prove-It
Don't start by fixing. Write a test that reproduces the bug, confirm it fails, implement the fix, confirm it passes, then run the full suite for regressions. For the reproduce-localize-reduce-fix-guard triage itself, use the `systematic-debugging` skill; this skill owns the test that guards the fix.

## Standards

- **Test state, not interactions.** Assert the outcome of an operation, not the internal calls that produced it. Interaction-based tests break on harmless refactors.
- **DAMP over DRY in tests.** Each test should read like a complete specification on its own; some duplication in tests is worth the clarity.
- **Prefer real dependencies.** Real implementation > fake > stub > mock. Reach for a mock only where the real thing is slow, non-deterministic, or has uncontrolled side effects.
- **One assertion per concept, descriptive names.** Name the behavior being verified, not "works" or "test 3".
- **Pyramid.** Most tests small and fast (unit); fewer integration; fewest E2E, limited to critical flows.
- **AAA and mock external dependencies.** Arrange-Act-Assert; mock only at real boundaries. Test behavior, not implementation.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "I'll write the tests after the code works." | You won't, and tests written after the fact test implementation, not behavior. |
| "It's too simple to test." | Simple code gets complicated; the test documents the expected behavior. |
| "Tests slow me down." | They do now, and pay it back every time the code changes. |
| "I tested it manually." | Manual testing doesn't persist. Tomorrow's change may break it with no way to know. |
| "The code is self-explanatory." | Tests are the specification of what the code should do, not what it does. |
| "Let me run the suite again to be sure." | After a clean run, repeating the command adds nothing unless code changed since. |

## Red flags

- Behavior added or changed with no corresponding test.
- A "npm test"-style default used instead of this project's real command.
- A test that passes on the first run (it may not be testing what you think).
- A bug fix with no reproduction test.
- Tests that assert internal calls or framework behavior instead of application behavior.
- Skipping or disabling a test to make the suite green.

## Verification

- [ ] Every new/changed behavior has a test that failed before the change and passes after.
- [ ] The full suite passes, run with the project's own command.
- [ ] Bug fixes include a reproduction test.
- [ ] No test was skipped or disabled; coverage did not decrease.

For anything that runs in a browser, add runtime verification on top of unit tests via the `agent-browser` skill.

## References

- Design and code-quality standards: `references/code-quality.md`
- Uncertainty protocol (a failed or skipped test is uncertainty): `references/uncertainty-protocol.md`
