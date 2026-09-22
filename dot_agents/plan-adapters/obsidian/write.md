# Obsidian adapter — write

Create or overwrite one plan note with the given content.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; the CLI call below
  selects the vault with `vault=<obsidian.vault>`.
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
- The full intended content of the note.

## Recipe
1. Resolve the vault's on-disk path:

   ```bash
   obsidian vault=<obsidian.vault> vault info=path
   ```

   The output is the vault's absolute path on disk. `Vault not found.`
   means `obsidian.vault` names no known vault — the call failed; the
   CLI still exits 0, so judge by output text.
2. Use the Write tool on exactly:

   ```
   <vault-path>/<location>/<file>
   ```

   with the full intended content. The content passed is the entire note
   after the call: an existing note fully replaced, an absent one created.
   Never merge into or splice around existing content here.

The note is byte-exact the intended content. The Write tool creates
missing parent directories, so `<location>/` materializes with the first
note written inside it — write alone also covers an un-run init. The
content never rides through the CLI's `content=` argument: the CLI
rewrites `\n` and `\t` substrings in `content=` values into real
newlines and tabs, silently corrupting any note whose content contains
those literal sequences — plan files, full of shell recipes, are exactly
that content class.
