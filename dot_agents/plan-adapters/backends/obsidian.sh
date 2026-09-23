# shellcheck shell=bash
# Obsidian backend: plan notes inside an Obsidian vault.
# Sourced by the plan dispatcher; implements the six ops as obsidian_*
# functions. All ops but init and list take a <location>: the task's
# vault-relative subfolder, as printed by init and listed by list.
#
# Content ops (read, write, append, set-status) work directly on the vault's
# on-disk path, resolved via 'vault info=path': the CLI's content= argument
# rewrites \n and \t sequences into real newlines and tabs, silently
# corrupting plan files, and its read output appends a newline the note does
# not have (ADR-002: notes are byte-exact copies of the disk plan files).
# init and list go through the CLI: it has no folder-create command, so init
# materializes the subfolder with a probe note, and list enumerates what the
# CLI reports. The CLI always exits 0 and reports failures as 'Error:' /
# 'Vault not found.' output lines, so every call is judged by its output
# text, never its exit status.

# obsidian_vault: print the configured vault name.
obsidian_vault() {
  local vault
  vault="$(plan_config_get obsidian vault)"
  [[ -n "$vault" ]] || die "obsidian.vault is empty in the plans config"
  printf '%s\n' "$vault"
}

# obsidian_folder: print the vault-relative plans folder.
obsidian_folder() {
  local folder
  folder="$(plan_config_get obsidian folder)"
  folder="${folder%/}"
  [[ -n "$folder" ]] || die "obsidian.folder is empty in the plans config"
  plan_subst_repo_name "$folder"
}

# obsidian_run <args...>
# Run the CLI for the configured vault and print its combined output.
obsidian_run() {
  local vault
  vault="$(obsidian_vault)"
  command -v obsidian >/dev/null 2>&1 || die "the obsidian CLI is not installed"
  local tmp msg
  tmp="$(mktemp)"
  if ! obsidian "vault=$vault" "$@" > "$tmp" 2>&1; then
    msg="$(cat "$tmp")"
    rm -f "$tmp"
    die "obsidian CLI call failed${msg:+: $msg}"
  fi
  cat "$tmp"
  rm -f "$tmp"
}

# obsidian_vault_path: print the vault's on-disk path.
obsidian_vault_path() {
  local vault out
  vault="$(obsidian_vault)"
  out="$(obsidian_run vault info=path)"
  case "$out" in
    "Vault not found."*) die "obsidian CLI: no vault named '$vault'" ;;
    "Error:"*) die "obsidian CLI: $out" ;;
    "") die "obsidian CLI returned no vault path" ;;
  esac
  printf '%s\n' "$out"
}

obsidian_init() {
  [[ -n "${1:-}" ]] || die "usage: plan init <task-name>"
  plan_validate_task "$1"
  local vault location out
  vault="$(obsidian_vault)"
  location="$(obsidian_folder)/$1"
  out="$(obsidian_run folder "path=$location")"
  case "$out" in
    "Vault not found."*) die "obsidian CLI: no vault named '$vault'" ;;
    "Error: Folder "*"not found."*) : ;; # the subfolder is absent: create it below
    "Error:"*) die "obsidian CLI: $out" ;;
    *)
      printf '%s\n' "$location"
      return 0
      ;;
  esac
  # No folder-create command exists: materialize the subfolder with a probe
  # note, then delete the probe. Deleting a note never deletes its folder.
  out="$(obsidian_run create "path=$location/init-probe.md" content= overwrite)"
  case "$out" in
    "Error:"* | "Vault not found."*) die "obsidian CLI: $out" ;;
  esac
  out="$(obsidian_run delete "path=$location/init-probe.md")"
  case "$out" in
    "Error:"* | "Vault not found."*) die "obsidian CLI: $out" ;;
  esac
  out="$(obsidian_run folder "path=$location")"
  [[ "$out" != "Error:"* ]] || die "obsidian CLI: could not create folder '$location'"
  printf '%s\n' "$location"
}

obsidian_read() {
  [[ $# -eq 2 ]] || die "usage: plan read <location> <file>"
  plan_validate_file "$2"
  local path
  path="$(obsidian_vault_path)/$1/$2"
  [[ -f "$path" ]] || die "plan note not found: $1/$2"
  cat -- "$path"
}

obsidian_write() {
  [[ $# -eq 2 ]] || die "usage: plan write <location> <file>"
  plan_validate_file "$2"
  local dir
  dir="$(obsidian_vault_path)/$1"
  # Writing a note materializes its parent subfolder: write alone covers an
  # un-run init.
  mkdir -p -- "$dir"
  cat > "$dir/$2"
}

obsidian_append() {
  [[ $# -eq 2 ]] || die "usage: plan append <location> <file>"
  plan_validate_file "$2"
  local dir
  dir="$(obsidian_vault_path)/$1"
  mkdir -p -- "$dir"
  plan_append_file "$dir/$2"
}

obsidian_list() {
  local vault folder out
  vault="$(obsidian_vault)"
  folder="$(obsidian_folder)"
  out="$(obsidian_run folders "folder=$folder")"
  case "$out" in
    "Vault not found."*) die "obsidian CLI: no vault named '$vault'" ;;
  esac
  # The CLI prints the plans folder itself, its direct children, and all
  # deeper descendants: keep only the direct children, one task per line.
  # A missing plans folder surfaces as an Error: line, filtered out like
  # any other non-child line: empty output means no tasks.
  awk -v p="$folder/" 'index($0, p) == 1 && substr($0, length(p) + 1) !~ /\//' <<< "$out" | LC_ALL=C sort
}

obsidian_path() {
  [[ -n "${1:-}" ]] || die "usage: plan path <location>"
  local dir
  dir="$(obsidian_vault_path)/$1"
  [[ -d "$dir" ]] || die "plan folder not found: $1"
  printf '%s\n' "$dir"
}

obsidian_set_status() {
  plan_parse_set_status "$@"
  plan_set_status_in "$(obsidian_vault_path)/$PLAN_SS_LOCATION"
}