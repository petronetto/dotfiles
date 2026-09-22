# Obsidian adapter — append

Add content to the end of one plan note, creating the note if it is absent.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; the recipe chains
  read.md and write.md, whose recipes select the vault with
  `vault=<obsidian.vault>`.
- `obsidian.folder` — read from `~/.agents/plans.config.md`, the one
  global config that names this adapter. Replace any `<repo-name>` in the
  value with the repo's directory name; drop a trailing `/`; an empty
  folder is invalid. The vault-relative plans folder.
- `location=<dir>` — `<obsidian.folder>/<task-name>`: the task's
  vault-relative subfolder, already including the task name. The task
  name is its git-safe slug (lowercase letters, digits, hyphens), or
  `roadmap` for the branch-independent roadmap task.
- `<file>` — the note's name inside the task subfolder, `.md` included, as
  in read.md.
- The content to append.

## Recipe
1. Follow read.md's recipe with `<location>/<file>` to get the note's
   current content. The output `Error: File "<location>/<file>" not
   found.` means the note is absent — expected here, unlike in read.md;
   treat the current content as empty.
2. Follow write.md's recipe with `<location>/<file>` and, as the full
   intended content: the current content unchanged, then one blank line,
   then the content to append. When the note was absent, write only the
   content to append.

After the call the note is its previous content with the appended block
at the end; nothing before the appended block changes. A note created by
append is the note itself, not a fragment: its content is exactly the
appended block.
