# Flow — <task-name>

One row per step. This is the plan's review surface; the step files are the
detail layer. Keep this file in sync as steps are added, split, or reordered.

| # | Step | Delivers | Files | Depends | Verify |
| - | ---- | -------- | ----- | ------- | ------ |
| 000 | <step-name> | <one sentence> | <file(s)> | none / 001 | <typecheck / test / manual> |

## Flow notes
Two or three lines: strict sequence or parallel groups, cumulative vs
independent diffs, the riskiest step and why.

## Flow graph
Include only when dependencies branch. Omit this section for strictly linear
plans.

```mermaid
flowchart LR
  s000 --> s001
  s001 --> s002
```
