---
name: review
description: Run a strict maintainability review of the current diff and label findings by severity (Critical / Required / Nit / FYI). Use for a code quality review, code judo pass, or maintainability audit before merge.
---

# Review

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

### Severity labels

Label every finding so the author knows what is mandatory versus optional. Lead with what matters: a structural problem *is* the review, not ten cosmetics around it.

| Label | Meaning | Author action |
| --- | --- | --- |
| **Critical:** | Blocks merge: data loss, security hole, broken functionality | Must fix before merge |
| *(no label)* | Required change | Must address before merge |
| **Nit:** | Minor, optional (style or format) | May ignore |
| **FYI** | Informational only | No action |

## Approval Bar

Block on: unjustified structural regression, a visible code-judo path left untaken, files crossing 1000 lines, ad-hoc branching, scattered feature checks, unnecessary wrapper/cast churn, canonical-helper duplication, an obvious decomposition left undone. Don't approve on "behavior seems correct" alone.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "It works, that's good enough." | Working but unreadable, insecure, or structurally wrong code compounds into debt. |
| "I wrote it, so it's correct." | Authors are blind to their own assumptions; every change benefits from another set of eyes. |
| "We'll clean it up later." | Later rarely comes. The review is the quality gate; use it. |
| "The tests pass, so it's good." | Necessary but not sufficient: tests miss structural, security, and readability issues. |
| "Moving the code makes it cleaner." | Relocating complexity isn't reducing it; find the version where branches disappear. |

## Red flags

- Merging a change that was never reviewed.
- A review that only checks whether tests pass.
- An "LGTM" with no evidence of review.
- A refactor that moves code without shrinking the concepts a reader must hold.
- A change that grows an already-large file instead of decomposing it.
- Findings with no severity label, so the author can't tell what's required.
- Accepting "I'll fix it later" without a tracked follow-up.

## Verification

Before approving, confirm:
- [ ] All **Critical** and required findings are resolved, or explicitly deferred with a tracked reason.
- [ ] Where a code-judo path existed, the change reduced rather than relocated complexity.
- [ ] Tests pass, the build is clean, and the verification story is documented.
- [ ] No security issue, dead code, or un-scoped change was left in place.
