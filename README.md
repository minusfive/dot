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

## Global files

Global AI instructions and related configuration use the `home/` source tree. Each path mirrors its target under `$HOME`.

- `home/AGENTS.md` links to both `~/AGENTS.md` and `~/CLAUDE.md`.
- `home/.agents/` provides global agent skills.
- `home/.claude/` provides Claude settings, skills, and the Claude statusline command.
- `home/.copilot/` provides Copilot instructions and the Copilot statusline command.
- `home/.config/opencode/` provides the tracked OpenCode configuration files.

The OpenCode tool manages its own manifests, dependencies, and runtime files under `~/.config/opencode/`. The repository does not manage those files.

The declarations are in [`.config/mise/conf.d/bootstrap-dotfiles.toml`](./.config/mise/conf.d/bootstrap-dotfiles.toml). Inspect or apply them with:

```sh
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --dry-run
mise bootstrap dotfiles apply
```

Other files under `home/` can provide sources for mise bootstrap resources, such as the profile and GitHub configuration files in [`home/`](./home/).

Non-migrated application configuration remains managed by GNU Stow. The [`.stowrc`](./.stowrc) file sets `$HOME` as the target, and [`.stow-local-ignore`](./.stow-local-ignore) defines exclusions. Run the link step from the repository root:

```sh
./scripts/init.zsh --link
```

You can also preview the legacy links with:

```sh
stow -nvR .
```

Do not add new global AI files to the Stow surface. Add them under `home/` and declare their targets in the mise configuration instead.

## Programs

System package state is managed by [mise-en-place](https://mise.jdx.dev), with shared machine configuration in [~/.config/mise/config.toml](./.config/mise/config.toml) and [~/.config/mise/conf.d/](./.config/mise/conf.d/), and repo-local tooling in [./.mise/config.toml](./.mise/config.toml) and [./.mise/conf.d/](./.mise/conf.d/). This includes Homebrew formulae, Homebrew casks, and Mac App Store apps. [Homebrew](https://brew.sh) is now only an optional bootstrap helper, while development tooling and setup flows continue through `mise` and the [Zsh scripts](./scripts/).

---

<img alt="Workspace" src="./assets/workspace.png" width="100%"/>

---

## Development

This project uses the tools it manages, so setting up the machine should set everything up for development. Switching to
the repository directory should automatically install the project-specific dependencies via [mise-en-place](https://mise.jdx.dev).
