# Code-quality standards

Apply these while implementing each step.

**Be ambitious about structural simplification.** Prefer deleting complexity over rearranging it. If a reframing makes whole branches, helpers, or layers disappear, take it.

**Keep files small and cohesive.** Treat a file past ~1,000 lines as a design smell; extract helpers or focused modules rather than letting it sprawl.

**Avoid spaghetti branching.** Push logic into a dedicated abstraction, helper, state machine, or module rather than scattering ad-hoc conditionals into unrelated flows.

**Program to interfaces and boundaries.** Keep logic in its canonical layer. Prefer explicit typed models and shared contracts over loosely-shaped ad-hoc objects. Make invariants explicit instead of relying on silent fallbacks.

**Prefer direct, boring, maintainable code.** Be skeptical of thin abstractions and pass-through helpers that add indirection without clarity. Prefer existing canonical utilities over bespoke one-offs.

**The best comment is not a comment at all.** Write clear, concise code instead of verbose comments that obscure intent.

**Test behavior, not implementation.** Use the AAA pattern and mock external dependencies. Run linters and tests where available, piping long output.
