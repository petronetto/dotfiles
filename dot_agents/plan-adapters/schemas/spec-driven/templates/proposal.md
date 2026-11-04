# Proposal

<!-- Use ASD-STE100. Define necessary terms at first use. Use ASCII only in
     diagrams and no em or en dashes. Remove template guidance when done. -->

## Why

<!-- Explain the motivation for this change. What problem does this solve? Why now? -->

## Goals

<!-- Concrete observable results. Words such as "fast" need a number or a check.
     Link each goal to requirement names and paths, without repeating behavior. -->
- G1: <observable result; requirement links or preservation check>

## Excluded Work

<!-- Related work not included in this change. -->

## What Changes

<!-- Describe what will change. Be specific about new capabilities, modifications, or removals. -->

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. Name each capability for a cohesive system
     behavior that can own related requirements as the system evolves. Do not name
     implementation tasks or proposal sections. Avoid broad catch-all names. Use
     kebab-case for path segments you introduce (e.g., user-auth or identity/user-auth)
     that follow the project's existing spec organization. Each creates
     specs/<capability-path>/spec.md. -->
- `<capability-path>`: <brief description of what this capability covers>

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec file.
     Use the exact existing capability path in the configured main-spec catalog.
     Leave empty if no requirement changes. A change with no capabilities at all
     (pure refactor, tooling, docs) must set `skip_specs: true` in its .change.yaml.
     A zero-delta change without that marker is invalid. Do not invent a requirement just to
     satisfy validation. -->
- `<existing-capability-path>`: <what requirement is changing>

## Impact

<!-- Affected code, APIs, dependencies, systems. For a pure refactor, state
     "No behavior change", name the preserved behavior and checks that prove it,
     and set skip_specs: true in .change.yaml. Do not create spec outputs.
     Record minor assumptions here when needed; resolve material ambiguity. -->
