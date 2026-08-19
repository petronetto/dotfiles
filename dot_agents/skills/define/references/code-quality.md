# Design and code-quality standards

These apply to both planning and implementation. The goal is a design so simple and direct it feels inevitable.

**Be ambitious about structural simplification.** Reframe the problem so whole branches, helpers, modes, conditionals, or layers disappear. Prefer deleting complexity over rearranging it. For every proposed step, ask: is there a "code judo" move that makes this dramatically simpler?

**Keep files small and cohesive.** Treat a file past ~1,000 lines as a design smell. When a step would push a file past that, plan a decomposition step first.

**Avoid spaghetti branching.** Push logic into a dedicated abstraction, helper, state machine, or module rather than scattering ad-hoc conditionals or special cases into unrelated flows.

**Program to interfaces and boundaries.** Keep logic in its canonical layer; avoid feature-specific logic leaking into general-purpose modules. Prefer explicit typed models and shared contracts over loosely-shaped ad-hoc objects. Make invariants explicit instead of papering over them with silent fallbacks.

**Prefer direct, boring, maintainable code.** Treat brittle or "magic" behavior as a design problem. Be skeptical of thin abstractions and pass-through helpers that add indirection without clarity. Prefer existing canonical utilities over bespoke one-offs.

**Clean the design, not just the behavior.** If behavior can stay the same while structure becomes meaningfully cleaner, choose the cleaner version. Prefer removing moving pieces over spreading the same complexity around.
