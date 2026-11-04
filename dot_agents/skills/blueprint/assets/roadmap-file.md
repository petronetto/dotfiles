# Roadmap: <Project Title>

<Explain why the project is split into these epics. Link to CHARTER.md for
vision, stack choices, and project boundaries. Use ASD-STE100 and ASCII
only in diagrams. Use no em or en dashes. Remove template guidance when done.>

**Status legend**: planned, in-progress, done, deferred

| ID | Epic | Intent | Scope boundary | Depends on | Status | Change |
| --- | --- | --- | --- | --- | --- | --- |
| E01 | <walking skeleton> | <one line> | In: <scope> / Deferred: <scope> | none | planned | |
| E02 | <name> | <one line> | In: <scope> / Deferred: <scope> | E01 | planned | |

## Flow graph
Include only when dependencies branch. Omit for a linear roadmap.

```text
        +--> E02
E01 ----+
        +--> E03
```

## Notes
`propose` stores `roadmap_entry: E01` (using the actual ID) in `.change.yaml`,
sets the epic in-progress, and fills the Change column with the returned
change location. `build` or `build-auto` sets it done only after every group
and the final audit clear their gates. `blueprint` re-plans the remainder on
request: update the roadmap first, then authorized affected change artifacts.
IDs are immutable once referenced. Scope shifts defer work to a sibling
epic; they never delete a row.
