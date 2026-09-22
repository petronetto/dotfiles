# Obsidian adapter — init

Create the task's subfolder in the vault. Idempotent: an existing
subfolder is left untouched. The plan notes themselves are created later,
one note per plan file inside `<location>/` (write.md), per ADR-002.

## Inputs
- `obsidian.vault` — read from `~/.agents/plans.config.md`, the one global
  config that names this adapter. The vault's name; every CLI call below
  selects the vault with `vault=<obsidian.vault>`.
- `obsidian.folder` — read from `~/.agents/plans.config.md`, the one
  global config that names this adapter. Replace any `<repo-name>` in the
  value with the repo's directory name; drop a trailing `/`; an empty
  folder is invalid. The vault-relative plans folder.
- `location=<dir>` — `<obsidian.folder>/<task-name>`: the task's
  vault-relative subfolder, already including the task name. The task
  name is its git-safe slug (lowercase letters, digits, hyphens), or
  `roadmap` for the branch-independent roadmap task.

## Recipe
1. Check whether the subfolder already exists:

   ```bash
   obsidian vault=<obsidian.vault> folder path="<location>"
   ```

   An existing subfolder prints `path`, `files`, `folders`, and `size`
   lines. Stop here: the subfolder exists, nothing is created.
2. The output `Error: Folder "<location>" not found.` means the subfolder
   is absent. The CLI has no folder-create command; a folder materializes
   when a note is created inside it. Create a probe note, then delete it:

   ```bash
   obsidian vault=<obsidian.vault> create path="<location>/init-probe.md" content="" overwrite
   obsidian vault=<obsidian.vault> delete path="<location>/init-probe.md"
   ```

   `overwrite` keeps the probe create idempotent: a probe left behind by an
   interrupted run is replaced, not duplicated as `init-probe 1.md`. The
   delete moves the probe to the trash and leaves the empty subfolder in
   place — deleting a note never deletes its folder.
3. Re-run the step-1 command; its output must now be the `path`/`files`
   lines.

The CLI reports failures as `Error:` lines and always exits 0 — judge
every call by its output text, never its exit status.
