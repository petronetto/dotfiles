# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), tuned to my
machine but usable as a reference for your own setup — adapt the personal bits
(SSH keys, git identity, machine-specific paths).

`chezmoi apply` needs no secret tool: the SSH public keys are committed directly
and the git email is prompted once during `chezmoi init`.
[1Password](https://1password.com/) provides the SSH agent and commit signing via
the [1Password SSH Agent](https://developer.1password.com/docs/ssh/), and is
optional.

## Private Dotfiles

Some sensitive configurations (SSH configs, private scripts, extra Zsh configs, etc.) are kept in a separate private repository. During setup, chezmoi automatically attempts to clone and sync files from this private repo via the `run_onchange_before_sync.sh.tmpl` script (`scripts/sync-private-dotfiles`). Don't worry though - if the private repo isn't accessible or doesn't exist, the installation will continue gracefully. It's completely optional!

Set the `PRIVATE_DOTFILES_REPO` environment variable to your own private dotfiles repository URL before running `chezmoi apply` to sync from it.

## Quick Start

### First Time Setup (macOS)

**Initialize and apply dotfiles**
```bash
curl -fsSL https://tinyurl.com/petronetto | bash
```

Or, without the short link:
```bash
curl -fsSL https://raw.githubusercontent.com/petronetto/dotfiles/main/bootstrap.sh | bash
```

This sets up your shell, tools, and SSH keys with no secret tool required.
You'll be prompted once for your git email during `chezmoi init`.

### Ubuntu 26.04 AMD64 bootstrap

Ubuntu support is in development. Do not deploy it to a workstation until the
Ubuntu acceptance checks pass. See the [Ubuntu setup checklist](docs/ubuntu.md)
for package owners, account setup, verification sources, and pending machine
checks. The macOS commands above retain their existing Xcode Command Line Tools
and Homebrew setup.

On the intended Ubuntu machine, bootstrap needs Bash, apt, network access, and
an existing non-root account with a home directory. A normal user also needs
working `sudo`. Bootstrap checks the OS, release, architecture, and target user
before package installation. Other Linux releases and ARM64 Ubuntu are refused.

Select the repository and branch explicitly when testing a published branch:

```bash
curl -fsSL https://raw.githubusercontent.com/petronetto/dotfiles/feat/ubuntu-support/bootstrap.sh \
  | bash -s -- --repo https://github.com/petronetto/dotfiles.git --branch feat/ubuntu-support
```

The branch must exist remotely for that example to work. To test unpublished
changes, copy the current public source into the isolated test machine, then use
that copy. Do not point a test at the primary machine's home or writable checkout:

```bash
bash /path/to/source/bootstrap.sh --source /path/to/source --profile test-container
```

Root-driven setup must name the existing target account:

```bash
bash /path/to/source/bootstrap.sh --source /path/to/source --user tester --profile test-container
```

Bootstrap installs sudo, CA certificates, curl, Git, GnuPG, archive utilities
(including `libarchive-tools` for `bsdtar` and `7zip` for AppImages), locales,
jq, and Zsh through apt, generates `en_US.UTF-8`, then installs chezmoi from its
official AMD64 glibc release if needed. It verifies the archive against the
release's SHA-256 checksums before extracting the binary with `bsdtar`. System packages use root privileges;
chezmoi and user-local files use the target account. It does not change the login
shell, sudo policy, or group membership. A normal-user run stops if elevation
fails. Root without `--user`, or with a root target, is refused.

Options:

- `--repo URL`: select an explicit Git repository URL.
- `--branch NAME`: select the source branch. An existing checkout on another
  branch is refused before apply; bootstrap does not reset or switch it.
- `--source DIR`: use an existing local tree, including changed files, without
  cloning a remote. This conflicts with `--repo` and `--branch`.
- `--user NAME`: select the non-root target for a root invocation. A normal user
  can select only their own account.
- `--profile workstation|test-container`: persist the selected profile in chezmoi
  data. New configurations default to `workstation`. A rerun without this option
  preserves the saved profile. Test mode suppresses private synchronization,
  including the template-time remote lookup, on later applies too. It does not
  replace the required tool catalog with a reduced installation.
- `--help`: print options without making changes. All options work with
  `bash -s --` when the script arrives through standard input.

`git_email` is prompted once. Isolated fixtures supply a synthetic address in
chezmoi configuration data; they must not use the production Git identity.
Required Ubuntu package, download, initialization, or apply failures stop the
bootstrap with a nonzero exit status and a named stage. Ubuntu does not use
`--keep-going`. Existing prerequisites are reused, with no automatic reset or
package removal. Review the managed diff before any later workstation apply.

Local checks require Bash and ShellCheck:

```bash
bash -n bootstrap.sh
shellcheck --shell=bash bootstrap.sh
```

These tests use temporary homes and source trees. System and network commands
are intercepted; the local-source tests use real chezmoi only on temporary data.
They do not prove real Ubuntu package installation or hardware support.

### Update Dotfiles

```bash
# Pull latest changes and apply
chezmoi update
```

## 1Password (optional)

[1Password](https://1password.com/) is the SSH-agent and commit-signing backend,
via the [1Password SSH Agent](https://developer.1password.com/docs/ssh/). It is
optional: `chezmoi apply` does not require it. The `1password` and
`1password-cli` casks are installed by `brew bundle` when you apply.

## Daily Workflow

### Making Changes

```bash
# Navigate to chezmoi source directory
chezmoi cd

# Edit files in the source directory (NOT in your home directory!)
vim dot_zshrc

# Apply changes to your home directory
chezmoi apply

# Commit and push changes
git add .
git commit -m "Update configuration"
git push
```

### Adding New Files

```bash
# Add a single file
chezmoi add ~/.myconfig

# Add a directory recursively
chezmoi add --recursive ~/.ssh/
```

## Essential Commands

```bash
chezmoi status          # Show what would change
chezmoi diff            # Show detailed changes
chezmoi apply           # Apply changes
chezmoi update          # Pull from git and apply
chezmoi cd              # Go to source directory
chezmoi add <file>      # Add file to chezmoi
chezmoi forget <file>   # Remove from chezmoi management
```

## Security

Chezmoi uses a **whitelist approach** - only files you explicitly add are managed.

Never committed to git, safe by default.

For secrets that need to be managed, see [chezmoi's guide on managing secrets](https://www.chezmoi.io/user-guide/manage-different-types-of-file/#keep-data-private).

## Resources

- [chezmoi Documentation](https://www.chezmoi.io/)
- [chezmoi Quick Start](https://www.chezmoi.io/quick-start/)
- [chezmoi User Guide](https://www.chezmoi.io/user-guide/command-overview/)
- [chezmoi Template Reference](https://www.chezmoi.io/reference/templates/)
