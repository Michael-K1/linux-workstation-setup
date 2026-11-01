# Linux Workstation Setup

A modular, interactive, distro-independent bootstrap for setting up a personal
Linux shell environment on fresh installations. Clone it, run it, answer a few
questions, and get a consistent Zsh setup everywhere: **Zsh + Oh My Zsh + a
prompt engine (Starship or Powerlevel10k) + Meslo Nerd Font + plugins + a
modular Zsh configuration**.

Designed as a personal configuration-management project (dotfiles + bootstrap
scripts), not a one-off install script:

- **Idempotent** - safe to run as many times as you like.
- **Interactive by default** - every component is individually selectable.
- **Non-interactive mode** - for automation and repeatable installs.
- **Non-destructive** - existing configs are detected, never overwritten
  without permission, and always backed up first.

## Supported distributions

| Distribution | Package manager | Strategy |
|---|---|---|
| Ubuntu       | APT        | Native packages |
| Debian       | APT        | Native packages |
| Arch Linux   | Pacman     | Native packages |
| CachyOS      | Pacman     | Native packages |
| Bazzite      | RPM-OSTree | Immutable-host-aware (see below) |

Detection uses `/etc/os-release` (`ID`, with an `ID_LIKE` fallback), not just
the presence of a package manager. Unsupported distributions get a clear
warning; you may continue at your own risk **only** if a supported package
manager was detected, otherwise the installer aborts.

> Installation behavior is **not** identical across distributions - see
> [Distro-specific notes](#distro-specific-notes).

## Requirements

- Bash 4+ (any modern distro).
- `git` and `curl` (or `wget`) - the installer offers to install them if
  missing (except on Bazzite, where they ship with the base image).
- `sudo` for system-level steps only (installing packages, `chsh` fallback).
  Everything else is strictly user-level. Never run the installer as root.

## Installation

### Quick start (curl)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Michael-K1/linux-workstation-setup/main/bootstrap.sh)"
```

With installer arguments (the `--` placeholder is required, it becomes `$0`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Michael-K1/linux-workstation-setup/main/bootstrap.sh)" -- -y
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Michael-K1/linux-workstation-setup/main/bootstrap.sh)" -- -n --prompt p10k
```

`bootstrap.sh` clones the repository into a **temporary directory**
(`mktemp -d` under `/tmp`) and hands off to `./install.sh`, forwarding all
arguments - the installer needs its `scripts/` and `config/` directories, so
it cannot be curl-piped on its own. After a successful run the temporary
clone is removed automatically; the installed environment never references
it (files are **copied**, not symlinked). After a failed run it is kept for
inspection - and since `/tmp` is cleared on reboot (which also covers
Bazzite's layering reboot), just re-run the one-liner afterwards.

Prefer a persistent checkout instead - for editing `settings.conf`, hacking
on the scripts, or re-running offline? Set `LWS_DIR`:

```bash
LWS_DIR=~/linux-workstation-setup bash -c "$(curl -fsSL https://raw.githubusercontent.com/Michael-K1/linux-workstation-setup/main/bootstrap.sh)"
```

A persistent checkout is created (or fast-forwarded on re-runs) at that path
and never deleted automatically.

Prefer the `bash -c "$(curl ...)"` form over `curl ... | bash`: it keeps
stdin attached to your terminal. Piping works too (the script re-attaches
`/dev/tty` for the menus), but the `bash -c` form is more robust - and as
with any remote script, feel free to read `bootstrap.sh` before running it.

### Manual (git clone)

```bash
git clone https://github.com/Michael-K1/linux-workstation-setup.git
cd linux-workstation-setup
chmod +x install.sh
./install.sh
```

### Interactive usage (default)

`./install.sh` walks you through:

1. Welcome screen and system detection (distro, package manager, immutability).
2. A status table of what is already installed.
3. One question per component - press **Enter** to accept the recommended
   default, or answer `y`/`n` to pick exactly what you want.
4. A summary of everything that will happen.
5. A final confirmation before any change is made.

Every step can be skipped individually; you can use this just to add a single
plugin or switch prompt engines.

### Non-interactive usage

```bash
# Everything from settings.conf, no questions asked:
./install.sh -n

# Same, but with overrides:
./install.sh -n --prompt p10k --set INSTALL_MESLO_NERD_FONT=false

# Interactive-but-lazy: accept all recommended defaults:
./install.sh -y
```

| Option | Effect |
|---|---|
| `-y`, `--yes` | Accept all recommended defaults, skip questions and confirmation |
| `-n`, `--non-interactive` | Fully unattended; apply settings file + overrides |
| `--settings FILE` | Use an alternative settings file |
| `--prompt ENGINE` | `starship` \| `p10k` \| `none` |
| `--set KEY=VALUE` | Override any setting (repeatable) |

Notes for unattended runs:

- Config files **not** created by this project are never overwritten.
- Changing the default shell requires a password (`chsh`/`sudo`), so in
  non-interactive mode it is only attempted via passwordless sudo; otherwise
  the installer tells you the exact command to run manually.

## Configuration defaults (`settings.conf`)

```bash
INSTALL_ZSH=true
INSTALL_OH_MY_ZSH=true
SET_DEFAULT_SHELL=true
PROMPT_ENGINE="starship"        # starship | p10k | none
STARSHIP_PRESET="tokyo-night"   # any `starship preset --list` name, or none
INSTALL_MESLO_NERD_FONT=true
PLUGIN_AUTOSUGGESTIONS=true
PLUGIN_SYNTAX_HIGHLIGHTING=true
DEPLOY_ZSH_CONFIG=true
```

These are *defaults*, not mandatory choices: interactive mode presents them as
the recommended answers, non-interactive mode applies them as-is, and
`--set KEY=VALUE` overrides either. Overrides are validated before anything
is installed: unknown keys, non-`true`/`false` booleans and invalid enum
values (e.g. `PROMPT_ENGINE`) abort the run with a clear error.

The built-in Oh My Zsh **git plugin is always enabled** by design and has no
setting - disabling it would break the plugin baseline this setup assumes.

## Prompt engines

### Starship (recommended default)

- Cross-shell, fast (Rust), TOML configuration, Git integration, command
  duration/status, language indicators, AWS/Kubernetes context.
- Installed natively via `pacman` on Arch/CachyOS; everywhere else the
  [official installer](https://starship.rs/) places a user-level binary in
  `~/.local/bin` (no root needed, no layering on Bazzite).
- The **tokyo-night preset** is applied by default via `starship preset`
  (no theme file lives in this repo - the preset ships with Starship
  itself). This only happens when `~/.config/starship.toml` does not exist
  yet; an existing config is never touched. Pick another preset or disable
  it with `--set STARSHIP_PRESET=<name|none>` (see `starship preset --list`).
- Configure via `~/.config/starship.toml`.
- Activated with `eval "$(starship init zsh)"` in `~/.config/zsh/prompt.zsh`.

### Powerlevel10k

- Zsh-specific, highly customizable, interactive configuration wizard
  (`p10k configure`), two-line prompts, Git status, and more.
- Cloned into `~/.oh-my-zsh/custom/themes/powerlevel10k`;
  `ZSH_THEME="powerlevel10k/powerlevel10k"` is set in `~/.zshrc`.
- Configure via `~/.p10k.zsh` (the wizard runs on first launch).

> **Note:** Powerlevel10k is in life-support mode - its maintainer has
> announced it receives very limited support and no new features. It still
> works perfectly well, but Starship is the recommended default.

The two engines are **mutually exclusive**: only the selected one is installed
and activated, never both.

### Switching prompt engines later

Just re-run the installer and pick the other engine:

```bash
./install.sh --prompt p10k      # or: starship | none
```

The installer re-renders `~/.zshrc` (theme line) and
`~/.config/zsh/prompt.zsh` for the new engine, backing up the old files.
Existing `~/.p10k.zsh` / `~/.config/starship.toml` files are never deleted, so
switching back and forth is lossless. Choosing `none` keeps your current
prompt configuration untouched. No font reinstall is needed - MesloLGS NF
works with both engines.

## Nerd Font (MesloLGS NF)

The installer downloads the four MesloLGS NF variants recommended by
Powerlevel10k (Regular, Bold, Italic, Bold Italic) from the
[powerlevel10k-media](https://github.com/romkatv/powerlevel10k-media)
repository into:

```
~/.local/share/fonts/MesloLGS-NF/
```

Already-present files are not re-downloaded; each file is validated as a real
TTF before being installed. The font cache is refreshed with `fc-cache` when
fontconfig is available (and skipped gracefully when it isn't).

**You must configure your terminal emulator manually** to use the
`MesloLGS NF` font - this cannot be automated reliably. In GNOME Terminal,
Konsole, Alacritty, kitty, etc., set the font in the profile/config.

**SSH users:** fonts are rendered by *your local* terminal. Install MesloLGS
NF on the machine you are sitting at, not (only) on the remote server.

## Plugins

| Plugin | Source | Purpose |
|---|---|---|
| `git` | built into Oh My Zsh | Git aliases and functions (always enabled) |
| `zsh-autosuggestions` | [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | History-based command suggestions |
| `zsh-syntax-highlighting` | [zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Live command highlighting |

External plugins are cloned into `~/.oh-my-zsh/custom/plugins/`. Already
installed plugins are detected and skipped. `zsh-syntax-highlighting` is
always placed **last** in the `plugins=()` array, as required by its
maintainers.

## Configuration structure

```
~/.zshrc                     Main entry point (standard Oh My Zsh template +
                             modular loader). Theme and plugin list are
                             rendered here by the installer.
~/.config/zsh/aliases.zsh    Custom aliases
~/.config/zsh/exports.zsh    Environment variables / PATH
~/.config/zsh/functions.zsh  Custom shell functions
~/.config/zsh/prompt.zsh     Prompt engine initialization (generated)
~/.zshrc.local               Optional machine-local overrides - never touched
                             by the installer
```

Modules in `~/.config/zsh/` are loaded alphabetically after Oh My Zsh, so
`prompt.zsh` conveniently loads last. Files deployed by the installer carry a
`managed by linux-workstation-setup` marker; anything without that marker is
treated as yours and is never overwritten without an explicit yes (and a
timestamped `*.bak.YYYYmmdd-HHMMSS` backup).

### Adding your own modules

Drop any `*.zsh` file into `~/.config/zsh/` - it is picked up automatically.
For machine-specific settings use `~/.zshrc.local`.

## Distro-specific notes

### Bazzite (immutable host)

Bazzite is an immutable, OSTree-based Fedora derivative, and the installer
treats it differently:

- **Zsh** is the only component that may need to be layered onto the host
  with `rpm-ostree install zsh` (asked explicitly, `--idempotent`).
  **Layered packages only become available after a reboot** - the installer
  tells you when this is needed. After rebooting, simply re-run
  `./install.sh`; it picks up where it left off.
- Everything else is deliberately user-level: Oh My Zsh, plugins and
  Powerlevel10k are git clones in `$HOME`; Starship goes to `~/.local/bin`;
  fonts go to `~/.local/share/fonts`. Nothing else is layered.
- `git`/`curl` ship with the Bazzite base image and are never layered. For a
  full development toolchain, prefer a
  [Distrobox](https://distrobox.it/) container rather than layering packages
  onto the host; this project intentionally keeps host changes minimal.
- Changing the default shell may require `sudo usermod -s` (or `lchsh`)
  instead of `chsh`; the installer falls back automatically and prints the
  manual command if that fails.

### Arch / CachyOS

`pacman -S --needed` is used, which skips already-installed packages. The
installer intentionally does **not** run a full system upgrade (`-Syu`), and
partial upgrades are unsafe on Arch - keep your system reasonably up to date
before running it.

### Ubuntu / Debian

`apt-get update` runs once before the first package installation. Starship is
not packaged in the default repositories, so the official installer is used
(user-level, `~/.local/bin`).

## Extending

### Adding a new plugin

1. Add a `PLUGIN_MYPLUGIN=true` default to `settings.conf`.
2. In `scripts/install-plugins.sh`, add a `clone_repo <url> "$(omz_plugins_dir)/myplugin"`
   block guarded by the setting.
3. In `scripts/configure-shell.sh` (`render_zshrc`), append the plugin name to
   `plugin_list` (keep `zsh-syntax-highlighting` last).
4. Optionally add a question in `interactive_configure` in `install.sh`.

### Adding a new distribution

1. Add its `ID` to the `case` in `scripts/detect-distro.sh` and map it to a
   package manager.
2. If it needs a new package manager, add a branch to `pkg_install` in
   `scripts/install-packages.sh` - this is the only place distro-specific
   package commands live.
3. Validate the install paths actually work on that distro before claiming
   support.

### Future ideas

Docker, AWS CLI, Terraform/OpenTofu, kubectl/Helm, Git/SSH configuration,
Neovim, VS Code, terminal emulator configs, more prompt engines (e.g.
Spaceship), more plugins. The step/module layout in `scripts/` is designed so
each of these becomes one new script plus one new menu entry.

## Safety model

- Every install function checks for an existing installation first.
- Remote install scripts (Oh My Zsh, Starship) are downloaded to a temp file
  and sanity-checked before execution - never piped straight from `curl`.
- Font downloads are validated as genuine TTF files.
- All config deployments are `cmp`-checked (no-op when identical), prompted
  when different, and backed up before replacement.
- `sudo` is used only where unavoidable (package installation, `/etc/shells`,
  `usermod`), and never in non-interactive mode where it could hang waiting
  for a password.
- Exit status is non-zero if any selected step failed, and the final report
  never claims success for a failed component.

## Known limitations

- **Bazzite:** installing Zsh requires a reboot mid-process (rpm-ostree
  layering); re-run the installer afterwards. This is inherent to immutable
  hosts.
- Terminal emulator font configuration is manual by design.
- `--set` overrides are not validated beyond `KEY=VALUE` shape (booleans are
  expected to be `true`/`false`).
- Uninstall is not implemented yet (planned as a future feature).
- Tested on Ubuntu (WSL2) during development; Arch/CachyOS and Bazzite code
  paths follow their documented procedures but should be validated in a VM
  before relying on them.

## License

[MIT](LICENSE)
