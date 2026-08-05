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

### First Time Setup

**Initialize and apply dotfiles**
```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply petronetto
```

This sets up your shell, tools, and SSH keys with no secret tool required.
You'll be prompted once for your git email during `chezmoi init`.

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
