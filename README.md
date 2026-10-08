# Personal System Config

This branch uses [Homebrew](https://brew.sh), [mise-en-place](https://mise.jdx.dev), [GNU Stow](https://www.gnu.org/software/stow/), and custom [Zsh](https://www.zsh.org/) scripts to configure macOS the way I like it.

I try my best to keep this and [my Nix-based configuration](https://github.com/minusfive/tree/nix) synchronized, but depending on which type of machine I'm working with more regularly, I may prioritize one configuration over the other.

> [!NOTE]
> This configuration includes several keyboard shortcuts (for app launching, window management, text editing, etc.), optimized to work with [my custom keyboard layout](https://github.com/minusfive/zmk-config) and workflow. To customize you'll likely want to primarily look at the following configurations:
>
> - [Hammerspoon](./.config/hammerspoon/)
> - [Wezterm](./.config/wezterm/)
> - [NeoVim](./.config/nvim/)

## Setup

> [!WARNING]
> This will modify system settings, install, and configure software. You should read and understand [the init script](./scripts/init.zsh) and the [other scripts it calls](./scripts/) before proceeding.

To setup a new machine or update a current one, run:

```sh
git clone --single-branch --branch main git@github.com:minusfive/dot.git ~/dev/dot
cd ~/dev/dot
./scripts/init.zsh
```

## Global files and configuration

> [!NOTE]
> This configuration is moving from GNU Stow to mise. Both systems remain in use while the migration continues.

The `home/` directory is a source tree for files that belong under `$HOME`. Its layout mirrors the target layout, so the source location also describes the installed location.

Mise declarations live in [`.config/mise/conf.d/`](./.config/mise/conf.d/). Files are grouped by logical boundary, such as `bootstrap-gh.toml` for GitHub resources and `bootstrap-ai.toml` for shared AI resources. This keeps each bootstrap area small and independently understandable.

Mise uses two related resource models:

- `[dotfiles]` describes user files that mise links, copies, templates, tracks, or removes. Its `symlink-each` mode lets a managed source tree coexist with files that an application owns itself.
- `[bootstrap.files]` describes files that bootstrap creates or renders. `[bootstrap.directories]` describes directory state such as permissions.

The [mise dotfiles documentation](https://mise.jdx.dev/dotfiles.html) and [mise bootstrap documentation](https://mise.jdx.dev/bootstrap.html) define the available resource modes and bootstrap phases.

The `--mise` initialization interface applies the package, file, repository, and dotfile phases. The `--link` interface remains available for configuration that still uses GNU Stow.

Non-migrated configuration remains managed by GNU Stow. The [`.stowrc`](./.stowrc) file defines `$HOME` as the target, and [`.stow-local-ignore`](./.stow-local-ignore) defines exclusions. A target belongs to one management system at a time.

## Programs

System package state is managed by [mise-en-place](https://mise.jdx.dev), with shared machine configuration in [~/.config/mise/config.toml](./.config/mise/config.toml) and [~/.config/mise/conf.d/](./.config/mise/conf.d/), and repo-local tooling in [./.mise/config.toml](./.mise/config.toml) and [./.mise/conf.d/](./.mise/conf.d/). This includes Homebrew formulae, Homebrew casks, and Mac App Store apps. [Homebrew](https://brew.sh) is now only an optional bootstrap helper, while development tooling and setup flows continue through `mise` and the [Zsh scripts](./scripts/).

---

<img alt="Workspace" src="./assets/workspace.png" width="100%"/>

---

## Development

This project uses the tools it manages, so setting up the machine should set everything up for development. Switching to
the repository directory should automatically install the project-specific dependencies via [mise-en-place](https://mise.jdx.dev).
