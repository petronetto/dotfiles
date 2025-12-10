# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Quick Start

### First Time Setup

```bash
# Initialize and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/petronetto/dotfiles.git
```

### Update Dotfiles

```bash
# Pull latest changes and apply
chezmoi update
```

## Daily Workflow

### Making Changes

```bash
# Edit files normally in your home directory, then add to chezmoi
vim ~/.config/zsh/.zshrc
chezmoi add ~/.config/zsh/.zshrc

# Or edit directly through chezmoi
chezmoi edit ~/.config/zsh/.zshrc

# Check what will change
chezmoi diff

# Apply changes
chezmoi apply
```

### Committing Changes

```bash
cd ~/.local/share/chezmoi
git add .
git commit -m "Update configuration"
git push
```

### Adding New Files

```bash
# Add a single file
chezmoi add ~/.config/newapp/config

# Add a directory recursively
chezmoi add --recursive ~/.config/newapp/
```

## Essential Commands

```bash
chezmoi status          # Show what would change
chezmoi diff            # Show detailed changes
chezmoi apply           # Apply changes
chezmoi update          # Pull from git and apply
chezmoi cd              # Go to source directory
chezmoi edit <file>     # Edit file in chezmoi
chezmoi add <file>      # Add file to chezmoi
chezmoi forget <file>   # Remove from chezmoi management
```

## Security

Chezmoi uses a **whitelist approach** - only files you explicitly add are managed. Sensitive directories are automatically excluded:
- `~/.config/1Password/`, `op/`, `configstore/`, `github-copilot/`, etc.

Never committed to git, safe by default.

For secrets that need to be managed, see [chezmoi's guide on managing secrets](https://www.chezmoi.io/user-guide/manage-different-types-of-file/#keep-data-private).

## Resources

- [chezmoi Documentation](https://www.chezmoi.io/)
- [chezmoi Quick Start](https://www.chezmoi.io/quick-start/)
- [chezmoi User Guide](https://www.chezmoi.io/user-guide/command-overview/)
- [chezmoi Template Reference](https://www.chezmoi.io/reference/templates/)
