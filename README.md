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

Use `home/` as the source tree for files that mise manages under `$HOME`. Mirror each target path below `home/`.

For example, use `home/.config/example/config.toml` as the source for `~/.config/example/config.toml`.

### Mise-managed files

Use `[dotfiles]` for user files that mise must link, copy, template, track, or remove. Store the source under `home/` and declare the target in a mise configuration file under [`.config/mise/conf.d/`](./.config/mise/conf.d/).

Name files in `conf.d/` by logical boundary. Use names such as `bootstrap-gh.toml` for one tool and `bootstrap-ai.toml` for one related group of tools.

Use `symlink` for one file:

```toml
[dotfiles]
"~/.config/example/config.toml" = { source = "../../../home/.config/example/config.toml", mode = "symlink" }
```

Use `symlink-each` for a directory that also contains files managed by another tool. Mise links only files in the source tree and leaves other target files in place:

```toml
[dotfiles]
"~/.config/example" = { source = "../../../home/.config/example", mode = "symlink-each" }
```

Read the [mise dotfiles documentation](https://mise.jdx.dev/dotfiles.html) for other modes and source options.

Use `[bootstrap.files]` when a bootstrap resource needs a copied or rendered file, explicit permissions, or a template. Use `[bootstrap.directories]` when a bootstrap resource only needs a directory with defined permissions:

```toml
[bootstrap.directories."~/.config/example"]
mode = "0755"

[bootstrap.files."~/.config/example/generated.toml"]
source = "../../../home/.config/example/generated.toml"
mode = "0644"
```

Read the [mise bootstrap documentation](https://mise.jdx.dev/bootstrap.html) for bootstrap phases and resource types.

Inspect or apply mise-managed files with:

```sh
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --dry-run
mise bootstrap dotfiles apply
```

Inspect or apply bootstrap files and directories with:

```sh
mise bootstrap files status
mise bootstrap files apply --dry-run
mise bootstrap files apply
```

Use one management system for each target. Do not declare the same target in both mise and GNU Stow.

### Legacy GNU Stow files

Non-migrated configuration remains managed by GNU Stow. The [`.stowrc`](./.stowrc) file sets `$HOME` as the target, and [`.stow-local-ignore`](./.stow-local-ignore) defines exclusions. Run the link step from the repository root:

```sh
./scripts/init.zsh --link
```

You can also preview the legacy links with:

```sh
stow -nvR .
```

Add new global files under `home/` and declare their targets with mise. Keep legacy Stow declarations for targets that have not migrated.

## Programs

System package state is managed by [mise-en-place](https://mise.jdx.dev), with shared machine configuration in [~/.config/mise/config.toml](./.config/mise/config.toml) and [~/.config/mise/conf.d/](./.config/mise/conf.d/), and repo-local tooling in [./.mise/config.toml](./.mise/config.toml) and [./.mise/conf.d/](./.mise/conf.d/). This includes Homebrew formulae, Homebrew casks, and Mac App Store apps. [Homebrew](https://brew.sh) is now only an optional bootstrap helper, while development tooling and setup flows continue through `mise` and the [Zsh scripts](./scripts/).

---

<img alt="Workspace" src="./assets/workspace.png" width="100%"/>

---

## Development

This project uses the tools it manages, so setting up the machine should set everything up for development. Switching to
the repository directory should automatically install the project-specific dependencies via [mise-en-place](https://mise.jdx.dev).
