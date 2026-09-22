# Disk adapter — append

Add content to the end of one plan file, creating the file if it is absent.

## Inputs
- `location=<dir>` — printed by `resolve.sh`.
- `<file>` — the file name inside the task's plan directory.
- The content to append.

## Recipe
1. Use the Read tool on `<location>/<file>` to get its current content. If
   the Read fails because the file is absent, treat the current content as
   empty — an absent file is expected here, unlike in `read.md`.
2. Use the Write tool on `<location>/<file>` with: the current content
   unchanged, then one blank line, then the content to append. When the
   file was absent, write only the content to append.

After the call the file is its previous content with the appended block at
the end; nothing before the appended block changes.
