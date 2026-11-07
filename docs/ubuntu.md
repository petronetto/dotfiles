# Ubuntu secondary workstation

Status: in development. Package installation has been exercised in an AMD64
Ubuntu 26.04 fixture.

## Bootstrap and ownership

Use the [bootstrap options](../README.md#ubuntu-2604-amd64-bootstrap). A normal
user needs working sudo. Root must select an existing non-root account with
`--user`. Root installs system packages; the target account owns runtime,
application, font, and managed configuration files.

The persisted `test-container` profile disables private synchronization before
its remote lookup. It does not remove required applications. Service suppression
requires a container with an explicit `policy-rc.d` that denies startup. It is
not a workstation bypass for service consent. No passwordless sudo is configured.

`.chezmoidata/ubuntu.yaml` is the Ubuntu catalog. It is not the macOS Brewfile.
Each selected tool has one installation owner. Bootstrap installs prerequisites
before chezmoi can run Zsh lifecycle scripts. Supporting archive and font tools
are dependencies, not additional selected end-user tools.

When chezmoi is missing, Ubuntu bootstrap downloads the latest stable official
AMD64 glibc release, verifies its SHA-256 checksum, and extracts only the binary
with `bsdtar`. This avoids the official shell installer's hardcoded GNU tar
extraction, which fails on nested paths in the AMD64 emulation fixture. The
macOS installation path is unchanged. The resolved version, source URL, and
archive digest are recorded in
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/bootstrap-chezmoi.json`.
Download metadata and archives remain under
`${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/bootstrap/` for diagnosis.

## Selected applications and commands

- Ubuntu apt owns Zsh (`zsh`), Git (`git`), curl (`curl`), jq (`jq`), Ghostty
  (`ghostty`), ripgrep (`rg`), fd (`fd`), bat (`bat`), fzf (`fzf`), zoxide
  (`zoxide`), lsd (`lsd`), delta (`delta`), GitHub CLI (`gh`), procs (`procs`),
  gum (`gum`), HTTPie (`http`), Atuin (`atuin`), tmux (`tmux`), and
  Neovim (`nvim`). User-local links normalize Ubuntu's `fdfind` and `batcat`
  names when needed. Distribution binaries are not replaced.
- Bootstrap installs official chezmoi (`chezmoi`). Official release artifacts
  install mise (`mise`), Starship (`starship`), Herdr (`herdr`), ast-grep
  (`ast-grep`), tlrc (`tldr`), Worktrunk (`wt`), and the LocalSend `.deb`
  (`localsend_app`). These tools are not mise backends.
- Mise owns only Node (`node`) and its bundled `npm` and `npx`. The tested
  selection is Node **24.22.1**, with npm **11.19.1**. Fresh login shells use
  mise shims. The npm prefix is `~/.local`, without privileged npm installation.
- Official npm packages install Pi (`pi`), selected version **1.4.0**,
  Todoist CLI (`td`), selected version **5.8.0**, and agent-browser
  (`agent-browser`), selected version **0.41.2**. The package names are
  `@earendil-works/pi-coding-agent`, `@doist/todoist-cli`, and `agent-browser`. Installation uses
  pinned package versions, registry integrity checks, and `--ignore-scripts`.
  Transitive npm dependencies are not a hermetic lock of future installations.
- Vendor apt repositories own native 1Password (`1password`), 1Password CLI
  (`op`), Brave (`brave-browser`), and Docker Engine (`docker`) with its Compose
  (`docker compose`) and Buildx (`docker buildx`) plugins. Each repository uses
  its own signing key, not global apt trust. 1Password uses the vendor-managed
  keyring and source paths to avoid conflicting duplicate repositories.
- The official AMD64 Obsidian `.deb` owns the desktop application. Provisioning
  copies its bundled official CLI to `~/.local/bin/obsidian` (`obsidian`), as
  documented upstream. It is not a community npm CLI or Obsidian Headless.
- The official Zed archive owns Zed (`zed`). A versioned user application bundle
  has stable command and desktop launchers. Runtime shared libraries come from
  apt; GPU compatibility remains a real-machine check.
- The official Todoist AppImage owns Todoist (`todoist`). 7-Zip extracts it into
  a versioned user application directory, without FUSE or snapd. The generated
  launcher runs the application directly. It does not use vendor AppRun or the
  vendor desktop entry, which can add `--no-sandbox`. A sandbox failure must be
  reported, not hidden by disabling the Chromium sandbox.

## Fonts and distribution verification

Provisioning installs Nerd Fonts **3.5.1** from their official release archives.
The tested families are `JetBrainsMono Nerd Font Mono` (also `JetBrainsMono NFM`)
and `CaskaydiaCove Nerd Font`. Fontconfig must discover the requested family;
a fallback font fails installation. Zed also provides its own UI fonts.

```sh
fc-match -f '%{family}\n' 'JetBrainsMono NFM'
fc-match -f '%{family}\n' 'CaskaydiaCove Nerd Font'
```

Cataloged GitHub/upstream release artifacts with published SHA-256 values are
pinned and checked before installation. Bootstrap resolves and records the
latest stable chezmoi release rather than pinning it. Vendor packages use signed apt repositories. The
Todoist AppImage source does not publish a checksum in the selected download
flow: its record states `https-only` and records the downloaded content hash.
That hash identifies the tested file; it is not an independent vendor signature.

Ubuntu extraction uses `bsdtar` from `libarchive-tools` for tar archives and
`7zip` for Todoist. The AMD64 Rosetta fixture exposed failures in GNU tar's
nested-directory extraction and direct AppImage execution. These archive
choices apply equally to workstation and test profiles; no architecture switch,
package downgrade, executable patch, or sandbox relaxation is used.

Installation records are stored at
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/ubuntu-packages.json`. They include
installed versions, owners, sources, checksums or verification methods, and font
discovery. Staging downloads remain under
`${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/ubuntu/` for diagnosis. Review that state
before any manual cleanup. Catalog, runtime, and installer changes rerun the
lifecycle installer through their content hashes.

## Account and desktop setup checklist

Complete these steps on the intended machine, not through automated fixture login:

1. Open Ghostty and Zed. Check native OpenGL/Vulkan rendering, launchers, fonts,
   and window shortcuts. A container display does not prove native GPU support.
2. Start Herdr in a PTY. Its shared preference is Zsh with an F4 prefix. The
   physical Fn/F4 keyboard mapping is a separate check; the macOS remap installer
   must not run on Linux.
3. Open 1Password and complete sign-in. Enable the SSH agent and, if needed,
   CLI integration and system authentication through the app. Confirm the Linux
   agent socket and `/opt/1Password/op-ssh-sign` helper before real signing.
   Installation and configuration inspection do not require an unlocked account.
4. Start Pi and use `/login` and `/model` to select the intended account/provider.
   Do not assume a primary-machine local model server or MLX model is available.
   Fixture tests must not make billed model requests.
5. Open Todoist and complete sign-in. Configure the official Todoist CLI through
   its interactive authentication flow. Do not put tokens in the catalog or logs.
6. Open Obsidian, select the intended vault, and enable Command line interface
   in Settings, General. The CLI executable is already registered. Personal
   vaults and optional Sync accounts are never fixture inputs.
7. Open Brave and complete any optional browser/account setup manually.
8. Review the separate Docker service and access decisions below.

## Touchpad momentum scrolling

Ghostty and Zed do not coast after you lift your fingers on Linux (upstream
requests: [Ghostty](https://github.com/ghostty-org/ghostty/discussions/4193),
[Zed](https://github.com/zed-industries/zed/issues/14473)). This is an
experimental workaround, not a fix. `~/.local/bin/touchpad-momentum` reads the
touchpad and, after a fast two-finger flick, keeps scrolling through a virtual
mouse wheel. The `focused-window-class` GNOME Shell extension tells it which app
has focus, so only Ghostty and Zed get the extra momentum.

`scripts/ubuntu/install-touchpad-momentum` installs a udev rule (needs sudo),
registers the extension and starts the `touchpad-momentum` user service. Log out
and back in once so GNOME loads the extension. The rule lets processes in your
desktop session read touchpad events and create virtual input devices.

Settings live in `dot_config/touchpad-momentum.env`. Raise `TPM_GAIN` or
`TPM_TAU` for more coasting, and set `TPM_DIRECTION=-1` if it runs the wrong
way. Restart with `systemctl --user restart touchpad-momentum`. Check it with
`journalctl --user -u touchpad-momentum`. To remove it, run
`systemctl --user disable --now touchpad-momentum`.

## Shell and keybinding behavior

Antidote and TPM are primed by provisioning (`scripts/install-packages`), never
cloned by shell startup. Provisioning clones the managers and generates the
static Antidote bundle (`.zsh_plugins.zsh`) from `zsh_plugins.txt`. It installs
the TPM plugins listed in `tmux.conf` after the package step provides `tmux`.
The lifecycle script derives `ZDOTDIR` the same way `.zshenv` does, so the
primed files land in `~/.config/zsh` even when provisioning runs without a login
shell. Interactive Zsh and tmux startup then load the primed files directly.
Startup only regenerates the bundle when the plugin list is newer than the
bundle, and a missing plugin cache reports a warning instead of downloading.

Linux shell behavior differs from macOS in these areas:

- Clipboard: navigation helpers use `wl-copy` on Wayland and `xclip` on X11
  instead of `pbcopy`. Without either service the helpers keep their normal
  textual behavior and never fail the shell.
- Locale: shell startup replaces an unavailable locale with an installed one
  instead of failing.
- Runtime paths: session-provided `XDG_RUNTIME_DIR` values are preserved;
  headless SSH sessions do not invent a desktop runtime directory.
- Optional helpers: Homebrew, `pbcopy`, the macOS Docker launcher, and macOS
  1Password paths stay macOS-only. Linux uses `~/.1password/agent.sock` and the
  `/opt/1Password/op-ssh-sign` helper.
- Atuin: Ubuntu keeps the apt package and uses its supported `fuzzy` search
  mode. macOS retains `daemon-fuzzy`; all other shared Atuin settings remain
  the same.
- Local models: Pi and Zed start without the primary machine's Ollama server or
  MLX models. Live provider and account selection stays interactive. Ollama is
  not deployed on Ubuntu: the `ollama` Zsh helper and the Pi Ollama discovery
  extension are excluded from non-macOS deployment, and no rendered Ubuntu
  setting references an Ollama model.

Keybinding notes:

- Ghostty quick-terminal shortcut is `ctrl+shift+space` on Ubuntu and
  `cmd+shift+space` on macOS. The macOS option-as-alt remap does not run on
  Linux.
- Herdr keeps the shared F4 prefix on both platforms. On Apple hardware,
  `scripts/ubuntu/configure-apple-keyboard` installs keyd and maps Fn to F4. It also
  swaps Ctrl and Cmd. The macOS remap installer does not run on Ubuntu. Check
  that the Fn key emits an event on the T2 Mac (`sudo keyd monitor`).
- Provisioning sets Zsh as the login shell (`scripts/ubuntu/set-default-shell`). It
  applies at the next login.
- Ghostty uses `font-size = 14` on Linux (20 on macOS).
- Core aliases (`vim`, `cat`, `dc`, and navigation helpers) resolve to installed
  Ubuntu tools with the same names as macOS.

## Docker privilege boundary

Installing Docker Engine packages can start privileged services on a workstation.
The installer requests consent before that installation. Declining returns a
required failure without changing service or user access policy. Conflicting
Docker/Podman/containerd packages are reported; they are never removed silently.

The container profile requires service-start denial for Docker and containerd.
It tests clients and local Compose/Buildx document processing, not an inner daemon.
It has no host Docker socket or privileged sidecar. The target user is not added
to the Docker group, which grants root-equivalent access. Keep using explicit
sudo unless you separately approve a different access policy.

On a real machine, daemon enablement, a container execution test, and any access
changes need separate approval. Docker Desktop and a container VM are not Ubuntu
installation targets.

## Pending machine checks

Pending checks are not passing CLI tests: native graphics, desktop-session
integration, real-account sign-in, vault selection, SSH-agent use, real Git
signing, and host Docker daemon/container execution. The acceptance report must
list these separately from executed CLI results.

Touch ID on the T2 Mac uses [t2touch](https://github.com/macintog/t2touch), an
experimental fprintd service that can enroll fingers from Linux on a Mac without
macOS. It is opt-in: provisioning never installs it. Run
`scripts/ubuntu/install-t2touch` yourself. The script builds a DKMS kernel module
and installs root services from a reviewed, pinned commit. It does not edit PAM:
enable fingerprints with `sudo pam-auth-update --enable fprintd` only after
`fprintd-verify` matches. Upstream verified it on one MacBookPro16,1 and says
macOS may remove the fingerprints and keychain if the Mac also boots macOS.
Provisioning does not add T2 kernel repositories, change encrypted disks,
restore macOS, or enable passwordless sudo. Password authentication is retained.
