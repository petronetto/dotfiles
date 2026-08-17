# Dotfiles (chezmoi)

This project is my dotfiles: a chezmoi-managed collection of configuration files and scripts that sets up and maintains my development environment on macOS.

## Project Layout

| Path | Purpose |
| --- | --- |
| `dot_<name>/` | Deploys to `~/<name>` (`dot_config/` → `~/.config/`, `dot_agents/` → `~/.agents/`, `dot_claude/` → `~/.claude/`) |
| `.chezmoiscripts/` | Lifecycle scripts (`run_once_*`, `run_onchange_*`), executed in name order during apply |
| `scripts/` | Repo-local helper CLIs, never deployed (`.chezmoiignore`); invoked from `.chezmoiscripts` via `{{ .chezmoi.sourceDir }}` |
| `private/` | Local-only private repo, gitignored and chezmoi-ignored; synced to `$HOME` separately (see [private/AGENTS.md](private/AGENTS.md)) |
| `.plans/`, `images/` | Repo-only working assets, never deployed |
| `Brewfile`, `bootstrap.sh` | Package manifest and one-shot installer; repo-only but watched by `run_onchange` scripts |
| `.chezmoi.toml.tmpl` | chezmoi config template; template data (e.g. `git_email`, prompted once at init) |

## Hard Rules

- **Never edit deployed files directly.** Files in `$HOME` (`~/.config`, `~/.zshrc`, `~/.agents`, `~/.claude`, ...) are chezmoi targets: hand edits are overwritten by the next `apply`. Make all changes in this source directory. To adopt an out-of-band change made in `$HOME`, use `chezmoi add <file>` (new file) or `chezmoi re-add` (modified managed file).
- **Never run `chezmoi apply` or `chezmoi update` unless asked.** `chezmoi apply --dry-run`, `chezmoi diff`, `chezmoi status`, and `chezmoi managed` are safe and preferred for verification.

## Security

This repository is public on GitHub. Never commit credentials, secrets, API keys, tokens, or personal data, and keep internal details (machine-specific paths, private infrastructure, work-related information) out of files, docs, and commit messages. The only exception is the gitignored `private/` folder.

## Chezmoi Guidelines

- Follow chezmoi naming conventions: `dot_`, `private_` (0700/0600), `executable_`, `symlink_`, `run_once_`/`run_onchange_`, `.tmpl` suffix for templates.
- `run_onchange` scripts re-run when their rendered content changes; several embed content hashes as comments to watch other files (e.g. the `Brewfile`). Never remove those lines, they are the trigger.
- Use templates (`.tmpl`) when configuration must vary across machines; data comes from `.chezmoi.toml.tmpl` and `.chezmoi.os`.
- Use the /find-docs skill if you need help with chezmoi templates or configuration.

## Skills

Skills live in `~/.agents/skills/` and are shared across agent tools (pi and Zed read that path directly; others via the symlinks in `dot_claude/`). There are two kinds:

- **Custom skills**: versioned in this repo under `dot_agents/skills/<name>/SKILL.md`. Edit them here.
- **Third-party skills**: never committed. Tracked only by the manifest `dot_agents/skills/skills.txt` (one `owner/repo/skill` entry per line) and installed into `~/.agents/skills/` at apply time when the manifest changes.

To change third-party skills permanently, edit the manifest in this repo. The `scripts/skills` helper only affects the local machine: it updates the deployed manifest, which is regenerated from the repo copy on the next apply.

## Code Style and Structure

- Write clean, maintainable and technically accurate code.
- All shell scripts must be compatible with Zsh on macOS (`bootstrap.sh` is the Bash exception: it runs before Homebrew exists).
- Never use an approach you're not confident about. If you're unsure about something, ask for clarity.
- Always follow best practices for Zsh and macOS system configuration.
- This project should work on macOS with minimal dependencies.
- Verify shell changes with `zsh -n` (or `bash -n` for `bootstrap.sh`) and respect `.editorconfig` (2-space indent, LF, final newline).

This project is open source on GitHub: follow best practices to keep it easy to understand, modify, and contribute to. Follow Conventional Commits, scoping when it helps (e.g. `feat(zsh):`, `chore(skills):`), matching the existing history.
