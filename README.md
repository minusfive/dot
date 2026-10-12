# Personal System Config

This branch uses [Homebrew](https://brew.sh), [mise-en-place](https://mise.jdx.dev), and custom [Zsh](https://www.zsh.org/) scripts to configure macOS the way I like it.

I try my best to keep this and [my Nix-based configuration](https://github.com/minusfive/tree/nix) synchronized, but depending on which type of machine I'm working with more regularly, I may prioritize one configuration over the other.

> [!NOTE]
> This configuration includes several keyboard shortcuts (for app launching, window management, text editing, etc.), optimized to work with [my custom keyboard layout](https://github.com/minusfive/zmk-config) and workflow. To customize you'll likely want to primarily look at the following configurations:
>
> - [Hammerspoon](./home/.config/hammerspoon/)
> - [Wezterm](./home/.config/wezterm/)
> - [NeoVim](./home/.config/nvim/)

## Setup

> [!WARNING]
> This will modify system settings, install, and configure software. You should read and understand [the init script](./scripts/init.zsh) and the [other scripts it calls](./scripts/) before proceeding.

To setup a new machine or update a current one, run:

```sh
git clone --single-branch --branch main git@github.com:minusfive/dot.git ~/dev/dot
cd ~/dev/dot
./scripts/init.zsh
```

## Profiles

The bootstrap supports two profiles: `work` and `personal`. The `work` profile
is the default and is the safer choice for a new machine.

Select a profile with `--profile`:

```sh
./scripts/init.zsh --profile personal --mise
```

The script stores the selected profile at
`${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and exports it as
`DOT_PROFILE`. Later runs use the stored profile unless you select another one.

Both profiles load the shared package set. The `personal` profile also loads
the Discord, SoftRAID, and WhatsApp casks. The selected profile also controls
which profile-specific `mise` environment is active.

Hammerspoon reads the same state file through the
[ProfileState Spoon](./home/.config/hammerspoon/Spoons/ProfileState.spoon/init.lua).
It mirrors the profile through `hs.settings`, which persists the value in
macOS defaults and makes it readable by other applications. The state file
remains the source of truth.

## Global files and configuration

> [!NOTE]
> Global application configuration is managed by mise.

The `home/` directory is a source tree for files that belong under `$HOME`. Its layout mirrors the target layout, so the source location also describes the installed location.

Mise declarations live in [`home/.config/mise/conf.d/`](./home/.config/mise/conf.d/) and are linked into `~/.config/mise/`. Files are grouped by logical boundary, such as `module.gh.toml` for GitHub resources and `module.profiles.toml` for rendered workspace profiles. This keeps each bootstrap area small and independently understandable.

Mise uses two related resource models:

- `[dotfiles]` describes user files that mise links, copies, templates, tracks, or removes. Its `symlink-each` mode lets a managed source tree coexist with files that an application owns itself.
- `[bootstrap.files]` describes files that bootstrap creates or renders. `[bootstrap.directories]` describes directory state such as permissions.

The [mise dotfiles documentation](https://mise.jdx.dev/dotfiles.html) and [mise bootstrap documentation](https://mise.jdx.dev/bootstrap.html) define the available resource modes and bootstrap phases.

The `--mise` initialization interface updates mise itself, then applies the package, file, repository, and dotfile phases.

Global files such as [`home/.editorconfig`](./home/.editorconfig),
[`home/.ssh/config`](./home/.ssh/config), and
[`home/.zshenv`](./home/.zshenv) are managed by their related mise boundaries:
EditorConfig has its own module, SSH configuration belongs to the
[`module.1password.toml`](./home/.config/mise/conf.d/module.1password.toml)
boundary, and the Zsh environment belongs to
[`module.zsh.toml`](./home/.config/mise/conf.d/module.zsh.toml).
Boundary-local development files for Hammerspoon and WezTerm live in their
matching `home/.config/...` source directories, and their mise declarations
exclude those files from runtime targets. A target belongs to one management
system at a time.

## Programs

System package state is managed by [mise-en-place](https://mise.jdx.dev), with shared machine configuration in [home/.config/mise/config.toml](./home/.config/mise/config.toml) and [home/.config/mise/conf.d/](./home/.config/mise/conf.d/), and repo-local tooling in [./.mise/config.toml](./.mise/config.toml) and [./.mise/conf.d/](./.mise/conf.d/). This includes Homebrew formulae, Homebrew casks, and Mac App Store apps. [Homebrew](https://brew.sh) is now only an optional bootstrap helper, while development tooling and setup flows continue through `mise` and the [Zsh scripts](./scripts/).

---

<img alt="Workspace" src="./assets/workspace.png" width="100%"/>

---

## Development

This project uses the tools it manages, so setting up the machine should set everything up for development. Switching to
the repository directory should automatically install the project-specific dependencies via [mise-en-place](https://mise.jdx.dev).
