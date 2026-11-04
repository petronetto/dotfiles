---
name: test
description: Prove behavior with tests, not by reading code. Use when implementing any logic, fixing any bug, or changing any behavior. Trigger on "test", "tdd", "prove it works", "regression test". Stack-agnostic; discovers the project's own test commands.
---

# Test

Tests prove behavior; source inspection alone does not. Write a failing test,
make it pass with the minimum code, then refactor while keeping it green.
For a bug, reproduce it in a test before changing the implementation.

## Input

New or changed logic, a bug, or error/boundary handling. Pure configuration,
documentation, or static content with no behavioral effect does not need new
behavioral tests. Existing tests can prove a behavior-preserving refactor.

## Steps

### 1. Discover the stack first

Find this project's actual commands before the first test:

- Build/test tools and checked-in wrappers such as `./gradlew`, `make test`,
  or repository scripts. Prefer these over global tools.
- Focused test and full suite commands.
- Test locations, filenames, and nearby conventions.
- Merge-gating commands in README, CONTRIBUTING, and CI.

Never assume a default such as `npm test`. Use commands from stack discovery.
Read `../../references/writing-tests.md`, `code-quality.md`, and
`definition-of-done.md` for applicable test and quality standards.

### 2. Run the test cycle

```text
RED: write a failing test --> GREEN: minimum code to pass
  --> REFACTOR: clean up while green --> repeat
```

Confirm the initial failure is caused by the behavior under test, not broken
setup. A new test that passes immediately does not show that it detects the
change; investigate before treating it as regression evidence.

For a bug, write a reproduction test, confirm failure, fix the cause, confirm
it passes, then run the full suite. Use `systematic-debugging` for diagnosis;
this skill owns the regression test. Do not postpone tests until code works.

### 3. Check behavior and reliability

- Assert outcomes and state, not internal call sequences. Interaction checks
  are appropriate only when the interaction itself is required behavior.
- Keep tests descriptive and self-contained. Some duplication is better than
  hiding the scenario behind elaborate helpers.
- Prefer real application logic. Use real dependencies where practical, then
  fakes, stubs, or mocks at external boundaries with slow, nondeterministic,
  or uncontrolled effects. Do not mock the flow being proved.
- Use Arrange-Act-Assert and one assertion concept per test. Multiple
  assertions can prove one outcome. Name the behavior, not "works".
- Keep most tests small and fast, fewer integration tests, and end-to-end
  checks for critical flows. Do not test framework mechanics.
- Add runtime verification through `agent-browser` for browser behavior, on
  top of unit tests. Manual checks alone do not provide persistent regression
  protection for behavior that can be automated.

### 4. Check completion

- Every new/changed behavior has a test that failed before and passes after.
- The full suite passes using the project's own command.
- Bug fixes include a reproduction test.
- No test was skipped or disabled; coverage did not decrease.
- The Definition of Done is satisfied for the change under test, not just
  the focused test result.

A failing, missing, or skipped check is uncertainty. Follow
`../../references/uncertainty-protocol.md`; do not claim completion.

## Output

Report the behavior tested, failure-before/pass-after evidence, commands and
results, full suite outcome, runtime verification, and any limits. Distinguish
executed checks from source inspection. Keep logs short or link captured logs.

## Guardrails

- Do not skip tests because code is simple, readable, or costly to test.
- Do not add behavior without corresponding behavioral coverage.
- Never skip or disable a test just to make the suite pass.
- Use this project's commands, not guessed defaults.
- Do not test internal calls or dependency behavior instead of application
  outcomes. Do not replace automated protection with "tested manually".
- After a clean run, do not repeat the same command without a relevant change.
- Passing tests alone do not replace the full Definition of Done.
