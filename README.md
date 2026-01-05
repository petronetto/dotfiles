# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), and uses 1Password for secret management and SSH authentication, via [1Password SSH Agent](https://developer.1password.com/docs/ssh/). This hopefully won't work out of the box for you becasue if it does, it means you have 1Password password, which is highly undesirable from my side 😂
It relies on my personal 1Password vault structure. However you can use it as a reference for setting up your own dotfiles with chezmoi and 1Password, by just removing the 1Password-specific parts. Search for `onepasswordRead` in the templates and remove or replace them with your own secret management solution.

I also prefer to install Homebrew, chezmoi and 1Password manually, becasue it works better for me that way on a fresh macOS installation.

## Quick Start

### First Time Setup

**Install Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Install required tools**
```bash
brew install chezmoi 1password 1password-cli
```

**Login to 1Password**

Open 1Password and sign in to your account and ensure that CLI access is set up.

**Initialize and apply dotfiles**
```bash
chezmoi init https://github.com/petronetto/dotfiles.git
chezmoi apply
```

### Update Dotfiles

```bash
# Pull latest changes and apply
chezmoi update
```

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
