# Writing tasks

Write `tasks.md` through `plan-cli`, using the selected schema. Read the
proposal, applicable specs, and design first. Read `CHARTER.md` through the
adapter when a roadmap exists. Stay inside its project-wide boundaries and
project instructions. Do not create separate per-change boundaries.

## Group by responsibility

Each task group has one responsibility. It must be possible to review and
revert it alone, and it must leave the code working. Use small, testable
changes, not unused structures or speculative scaffolding. One group is
enough for a small change; do not invent groups to fill a list.

Use descriptive `##` group headings. Each group has a plain `Depends:` line,
not a checkbox. Use `Depends: none` or the exact names of prerequisite groups.
Order groups after their dependencies. Dependencies must exist and have no
cycles. Groups with no dependency and disjoint files can run in parallel.
The group names are references, not numeric IDs.

## Write checkable actions

Use ASD-STE100 Simplified Technical English. Define necessary technical terms
at first use. Use active voice, common words, and one term per concept. Use
ASCII only in diagrams and no em or en dashes.

Each checkbox starts with a verb, has one action, names its files, and names
its requirement and scenario or preservation check. Include an observable
completion check in that same checkbox. For example:

```markdown
## Session expiration

Depends: none

- [ ] Enforce expiration in src/session.ts for "Expire inactive sessions"; check: "Reject a protected request at expiration" passes in tests/session.test.ts.
- [ ] Test inactivity reset in tests/session.test.ts for "Restart the inactivity period after successful access"; check: the focused session suite passes.
```

A check qualifies the action; it is not a second implementation action.
Separate independent actions. Avoid vague tasks such as "implement feature".
Use an exact manual check and expected result only where automation is not
possible. Do discovery while proposing, not as generic implementation work.

## Cover the contract once

Cover all requirements and scenarios, including removal and rename baseline
checks. For a pure refactor, link to the proposal's preservation checks.
Do not invent behavior or repeat requirements in the task list. Link to the
goals and behavior instead. Keep each fact in one place.

Each group includes the tests and documentation its work needs. Do not move
those obligations to a final group. A final integration group is useful only
when it checks a distinct system-level risk. Never add boilerplate test or
documentation work where none is needed.

Checks must cover `definition-of-done.md`, not just local acceptance criteria.
Name tests, build checks, linters, or exact runtime checks that prove the code
still works after each group alone. Obtain commands from stack discovery,
not invented defaults or a separate command inventory. Use the `test` skill
for behavioral test discipline, Arrange-Act-Assert, and external test doubles.

Resolve questions that would change behavior, approach, or task breakdown
before saving. Record minor assumptions in the relevant artifact; do not
silently turn assumptions into requirements. Keep optional workflow follow-up
as plain bullets outside tracked tasks. No extra tracking or review files
are needed.
