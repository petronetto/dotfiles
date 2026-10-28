# Writing tests

Tests protect application behavior. Each test must earn its maintenance cost by detecting a meaningful failure.

These rules apply to new and changed tests. Do not expand a task into an unrelated cleanup.

## Test behavior, not code structure

**Test what the application does, not how its implementation is arranged.** Exercise meaningful behavior through the interface used by callers. A behavior can be a business rule, an application flow, or a required side effect. It need not involve a user interface. [1]

Before adding a test, identify:

1. The requirement or realistic failure it protects against.
2. The input or condition that triggers the behavior.
3. The observable outcome that proves correctness.
4. The gap in existing tests that makes this test necessary.

If you cannot name a meaningful failure the test would catch, do not write it. Do not add tests just because a file, class, method, or branch exists.

## Test our responsibilities, not dependency mechanics

**Do not test third-party SDKs, frameworks, or language features. Test our use of them.**

Do not add standalone tests that only prove:

- An SDK method returns the value supplied by a mock.
- A framework provides its documented routing, serialization, or injection behavior.
- A DTO stores constructor arguments, exposes properties, or has generated equality methods.
- A configuration file contains a key, constant, or default already written in that file.
- A getter, setter, or pass-through wrapper forwards an unchanged value.
- Source text contains a function, annotation, comment, or particular implementation pattern.

**Behavior, not the file category, decides whether a test is useful.** Custom validation, data mapping, configuration precedence, startup failure, and serialization compatibility can be application responsibilities. Test their effects, not their declarations. Prefer a build, type checker, linter, or schema validator for static constraints.

For external integrations, test our request construction, response interpretation, and handling of relevant failures. A mock proves behavior under an assumed contract, not compatibility with the real provider. Use focused integration or contract tests when that compatibility is a material risk. Do not reproduce the provider's test suite. [2]

## Choose the smallest useful set

**Add tests for distinct risks, not for volume.** Reuse or extend existing coverage of the same behavior at the right level. Add a separate test when it protects a different requirement or failure.

- Cover the intended outcome and relevant failure paths, limits, or state transitions. Select cases from requirements, production risks, and known bugs, not arbitrary input combinations.
- Test business rules with focused tests. Test application flows across the real modules that participate in the flow. Keep end-to-end tests for critical journeys and risks that narrower tests cannot adequately cover.
- Choose the narrowest test that can expose the failure. Do not add the same scenario at every test level unless each level catches a distinct integration risk.
- Do not require a new test for a comment-only change or a behavior-preserving refactor already covered by suitable tests.
- Use coverage to find possible gaps, not as proof of correctness. Meet project requirements, but do not inflate coverage with assertions that protect no behavior.

For example, test that an order is not confirmed when payment fails, including any required persisted state. Do not replace that test with assertions that a mocked payment SDK returns the configured error.

## Keep tests trustworthy and easy to change

**A behavior-preserving refactor should not require rewriting behavioral assertions.** Setup may change when construction or dependency wiring changes. [1]

- Use Arrange, Act, Assert. Separate the stages with whitespace; do not add routine stage comments when the structure is already clear.
- Name tests after the condition and expected outcome, not the method name alone.
- Keep each test focused on one behavior. Multiple assertions are appropriate when they jointly establish that outcome, such as a rejected transaction and an unchanged balance.
- Assert results, observable state, and required side effects. Avoid private methods, internal fields, helper call sequences, or incidental call counts. An interaction assertion is appropriate when the interaction itself is a requirement, such as sending exactly one payment request.
- Keep real application logic in the test path. In fast tests, replace external I/O at the seam it crosses. Do not mock the application flow you claim to verify. Use real dependencies in focused integration tests when their behavior matters.
- Derive expected results from the requirement, not by calling the production logic again or copying its algorithm into the test.
- Control time, randomness, shared state, and external services. Tests must be independent and repeatable. Do not use sleeps to wait for asynchronous work when a condition or event can be awaited.
- Keep relevant inputs and assertions visible. Small fixture helpers are useful; a test framework built inside the test suite usually is not. Prefer a little duplication over hidden behavior. [1]
- Avoid broad snapshots that record incidental output. Use snapshots only when the reviewed representation is itself a meaningful contract.

For a bug fix, reproduce the failure before changing the implementation. Confirm that the regression test fails for the intended reason and passes after the fix. A setup error is not evidence that the test detects the bug.

## Use advanced techniques only when they add value

**Better tests do not necessarily mean more test cases.**

Property-based testing can check application invariants across many generated inputs, such as preservation of a balance or a custom encoder's round-trip behavior. Use it when a meaningful property and a broad input space justify it, not to retest a library. [3]

Mutation testing can reveal assertions that fail to detect meaningful changes in the implementation. Use it selectively for important logic; inspect surviving mutations before adding tests. An equivalent mutation or an irrelevant implementation change does not justify a new assertion. Do not introduce tooling or pursue a mutation score without a task-specific need. [4]

## Final review

Before keeping a test, ask: **What realistic application failure would go undetected without it?**

Remove additions that have no clear answer. Do not remove existing behavioral protection merely to reduce the test count.

## Sources and rationale

These are project rules informed by established engineering guidance, not a claim that every team uses the same policy. Property-based and mutation testing are established advanced techniques, not mandatory tools.

1. [Software Engineering at Google: Unit Testing](https://abseil.io/resources/swe-book/html/ch12.html): test behaviors through public interfaces, prefer state over incidental interactions, and keep tests complete, concise, and resistant to refactoring.
2. [Martin Fowler: Contract Test](https://martinfowler.com/bliki/ContractTest.html): test doubles do not establish compatibility with a real external service; focused contract tests address that gap.
3. [Hypothesis: Introduction](https://hypothesis.readthedocs.io/en/latest/tutorial/introduction.html): use generated inputs to check meaningful properties; property-based testing complements example-based tests.
4. [Google Testing Blog: Mutation Testing](https://testing.googleblog.com/2021/04/mutation-testing.html): evaluate whether tests detect code changes, with attention to which mutations provide useful feedback.
