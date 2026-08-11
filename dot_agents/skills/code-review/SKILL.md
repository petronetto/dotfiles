---
name: code-review
description: Run a strict maintainability review of the current diff — abstraction quality, file bloat, spaghetti-condition growth. Use for a code quality review, code judo pass, or maintainability audit.
disable-model-invocation: true
---

# Code Review

Review implementation quality and codebase health, not just correctness. Be **ambitious**: hunt for the "code judo" move that deletes complexity rather than rearranges it. And don't confine yourself to the diff — the best fix is often a file the diff didn't touch: a module to extend, a caller left inconsistent, a layer up that shrinks the whole change. Say so when it does.

## Core Prompt

> Audit the current branch's changes for quality, not just correctness.
> Find the code-judo move: a restructuring that preserves behavior but deletes complexity instead of moving it.
> Improve abstraction, modularity, succinctness, legibility. If the real fix lives outside the diff, say so.
> Be rigorous. Measure twice, cut once.

## Standards

1. **Code judo first.** One usually exists. Prefer it over any lesser cleanup.
2. **Diff isn't the boundary.** Files outside it are in scope — often the highest-value finding.
3. **1000-line ceiling.** Crossing it is a smell by default; extract instead.
4. **No spaghetti.** Ad-hoc conditionals dropped into unrelated flows are a design problem, not a nit.
5. **Design over "it works."** Same behavior, cleaner structure beats messy-but-working.
6. **Boring beats magic.** Distrust generic mechanisms and thin/pass-through wrappers.
7. **Clean boundaries.** Question casts, `any`, optionality where a clearer type could exist.
8. **Canonical layer.** Feature logic stays out of shared paths; reuse existing helpers.
9. **Atomicity.** Flag avoidable sequential orchestration and partial-update state.

## Deep-Module Lens

From `codebase-design`: **depth** (interface hides implementation vs. shallow wrapper), the **deletion test** (delete the module — does complexity vanish or reappear everywhere?), **seam discipline** (one adapter isn't a real seam). Use these to judge if an abstraction earns its keep.

## Flag Aggressively

Cleaner reframing available · files past 1000 lines · conditionals bolted onto unrelated paths · feature logic leaking into shared modules · thin/identity wrappers · unnecessary casts/optionality · copy-paste over extraction · "temporary" branching · duplicated canonical helpers · avoidable sequential orchestration · non-atomic partial updates.

## Preferred Remedies

Delete indirection, don't polish it · reframe state so conditionals vanish · extend existing abstractions instead of adding new ones · extract helpers · split large files · replace condition chains with a typed dispatcher · separate orchestration from logic · reuse canonical helpers · parallelize independent work.

Don't settle for "rename this" when the issue is structural.

## Tone & Output

Direct, not rude. Priority: structural regressions → missed code-judo → spaghetti growth → boundary/type issues → file size → modularity → legibility. Few high-conviction findings beat many nits.

## Approval Bar

Block on: unjustified structural regression, a visible code-judo path left untaken, files crossing 1000 lines, ad-hoc branching, scattered feature checks, unnecessary wrapper/cast churn, canonical-helper duplication, an obvious decomposition left undone. Don't approve on "behavior seems correct" alone.
