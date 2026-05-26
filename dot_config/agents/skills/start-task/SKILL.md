---
name: start-task
description: Start implementation work from a Jira ticket, a Sentry issue, or no ticket by creating the required Jira work item and switching to a task branch.
argument-hint: "<jira-key | sentry-issue | summary>"
---

# /start-task

Start work in a consistent flow:
1. Resolve the work source (Jira ticket, Sentry issue, or no ticket).
2. Ensure a Jira work item exists.
3. Create and switch to a branch named `<JIRA_KEY>-<slug>`.

Input: @$1

## Required command references

Always use these commands for discovery/execution:
- `acli jira workitem view --help`
- `acli jira workitem create --help`
- `sentry issue view --help`

## Decision flow

### 1) Jira ticket provided
Use this path when input matches a Jira key format like `ABC-123`.

1. Fetch the Jira item details:
   - `acli jira workitem view <JIRA_KEY> --json`
2. Build a slug from the Jira summary (lowercase, trim, replace spaces/invalid chars with `-`, collapse repeated `-`).
3. Create and switch branch:
   - `git checkout -b <JIRA_KEY>-<slug>`
4. Continue implementation work on that branch.

### 2) Sentry issue provided
Use this path when the input looks like a Sentry issue selector/ID (for example `@latest`, `org/ISSUE`, `PROJECT-X`, `123456`).

1. Fetch Sentry issue details:
   - `sentry issue view <SENTRY_ISSUE> --json`
2. Ask concise clarification questions only if needed to create Jira issue data (for example project key).
3. Create a Jira work item from Sentry context:
   - `acli jira workitem create --project "<PROJECT_KEY>" --type "Task" --summary "<derived summary>" --description "<sentry context>" --json`
4. Read created Jira key from JSON output.
5. Build slug from Jira summary and create/switch branch:
   - `git checkout -b <JIRA_KEY>-<slug>`
6. Continue implementation work on that branch.

### 3) No Jira ticket provided
Use this path when input is empty or a plain request without a Jira key.

1. Ask concise clarification questions needed to create Jira issue:
   - required: Jira project key
   - required: short summary (if not already provided)
   - optional: whether this should be `Task` or `Bug` (default to `Task`)
2. Create Jira work item:
   - `acli jira workitem create --project "<PROJECT_KEY>" --type "<Task|Bug>" --summary "<summary>" --description "<description>" --json`
3. Read created Jira key from JSON output.
4. Build slug from summary and create/switch branch:
   - `git checkout -b <JIRA_KEY>-<slug>`
5. Continue implementation work on that branch.

## Clarification rules

- If information is missing, ask the user one concise question at a time.
- Prefer the minimum questions required to proceed.
- Do not invent Jira project keys, issue IDs, or ticket metadata.

## Branch naming rules

- Final branch format: `<JIRA_KEY>-<slug>`
- Keep slug lowercase and git-safe.
- Maximize readability while keeping it short and specific.
