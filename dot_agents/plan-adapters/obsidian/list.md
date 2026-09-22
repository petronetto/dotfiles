# Obsidian adapter — list

Enumerate the task subfolders under the plans folder in the vault.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; every CLI call below
  selects the vault with `vault=<obsidian.vault>`.
- `obsidian.folder` — read from `~/.agents/plans.config.md`, the one
  global config that names this adapter. Replace any `<repo-name>` in the
  value with the repo's directory name; drop a trailing `/`; an empty
  folder is invalid. The vault-relative plans folder, the parent of every
  task subfolder.

## Recipe
Run exactly one command:

```bash
obsidian vault=<obsidian.vault> folders folder="<obsidian.folder>" | awk -v p="<obsidian.folder>/" 'index($0,p)==1 && substr($0,length(p)+1)!~/\//' | LC_ALL=C sort
```

The CLI prints `<obsidian.folder>` itself, its direct children, and all
deeper descendants, one vault-relative path per line; the awk filter keeps
only the direct children — one line per task subfolder, sorted. Empty
task subfolders (created by init.md, no notes yet) are listed too. Empty
output means no tasks: either no subfolder exists yet, or the plans
folder itself does not — an `Error: Folder ... not found.` line is
filtered out like any other non-child line.
