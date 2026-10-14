# Personal System Configuration

This repository manages my macOS configuration. It uses [mise][mise] and custom [Zsh][zsh] scripts.

The configuration includes keyboard shortcuts for application launchers, window management, and text editing. These shortcuts work best with my [custom keyboard layout][keyboard-layout].

## Setup

The initialization script changes system settings and installs software. Read the [initialization script](./scripts/init.zsh) and the scripts that it calls before you run it.

Clone the repository and initialize a machine:

```bash
git clone --single-branch --branch main git@github.com:minusfive/dot.git ~/dev/personal/dot
cd ~/dev/personal/dot
./scripts/init.zsh --mise
```

The `--mise` option is the fresh-machine entry point for the mise phase. The `work` profile is the default and is the safer choice for a new machine.

Select a profile with `--profile`:

```bash
./scripts/init.zsh --profile personal --mise
```

The script stores the selected profile at `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and exports it as `DOT_PROFILE`. Later runs use the stored profile unless you select another one.

Each profile loads a different set of `mise` modules. The selected profile controls the active profile-specific `mise` environment.

Hammerspoon reads the same state file through the [ProfileState Spoon](./home/.config/hammerspoon/Spoons/ProfileState.spoon/init.lua). It mirrors the profile through `hs.settings`. The state file remains the source of truth.

[Homebrew][homebrew] is optional for the mise phase. Mise installs declared package resources directly. Use `./scripts/init.zsh --brew` when you want the optional Homebrew helper.

## Repository layout

The `home/` directory is a source tree for files that belong under `$HOME`. Its layout mirrors the target layout, so each source path also describes its installed path.

Look in these directories when you customize the configuration:

- [Hammerspoon](./home/.config/hammerspoon/)
- [Neovim](./home/.config/nvim/)
- [WezTerm](./home/.config/wezterm/)

```text
.
├── .agents/                         # repository skills, eval workspaces, and guidance
├── .mise/                           # repository-local tools and tasks
├── assets/                          # images
├── home/                            # source tree mirrored under ~/
│   ├── .config/
│   │   ├── hammerspoon/             # ~/.config/hammerspoon
│   │   ├── mise/                    # ~/.config/mise
│   │   ├── nvim/                    # ~/.config/nvim
│   │   └── ...
│   ├── .ssh/
│   │   └── config                   # ~/.ssh/config
│   └── .zshenv                      # ~/.zshenv
├── scripts/                         # bootstrap and development tasks
├── tests/                           # script tests
└── ...
```

## Machine bootstrap

[mise][mise] manages global files, packages, and repository tools. Declarations for global configuration live in [home/.config/mise/conf.d/](./home/.config/mise/conf.d/). Mise links these files into `~/.config/mise/`.

The declarations are grouped by logical boundary. For example, `module.gh.toml` manages GitHub resources and `module.profiles.toml` manages rendered workspace profiles. This keeps each bootstrap area small and independently understandable.

Package resources use dedicated module files. Tightly coupled declarations share a module. `miserc.toml` selects the modules for each profile.

[dotfiles][mise-dotfiles] declarations describe user files that mise links, copies, templates, tracks, or removes. [bootstrap.files][mise-bootstrap] declarations describe files that bootstrap creates or renders, while [bootstrap.directories][mise-bootstrap] declarations describe directory state, such as permissions. Together, these declarations define the available resource modes and bootstrap phases.

The `--mise` initialization interface runs the complete declarative mise lifecycle. It applies managed files, packages, repositories, dotfiles, tools, and package hooks.

The mise phase uses one confirmation for the existing-mise self-update, the full bootstrap, workspace trust, and maintenance. Future bootstrap declarations become part of this phase without another script change.

An existing mise updates before bootstrap. A mise installed during the current run does not update again.

Bootstrap is not transactional. If a phase fails, fix the reported phase and rerun `./scripts/init.zsh --mise`.

## Development

The repository manages the tools that it uses for development. Entering the repository activates its project-specific `mise` environment.

Run the setup task to install project dependencies and install `hk` hooks that run through `mise`:

```sh
mise run setup
```

Run all configured checks:

```sh
mise run check
```

The [hk configuration](./hk.pkl) runs checks and fixes from one shared definition. Markdown checks preserve soft-wrapped prose and automatically reflow hard-wrapped paragraphs. The repository keeps its Markdown style choices, including its inline HTML allowlist.

![Workspace](./assets/workspace.png)

## Previous Nix configuration

I previously maintained a [Nix-based configuration][nix-config]. I no longer maintain it because this repository now replicates much of what I liked about Nix with `mise`.

[homebrew]: https://brew.sh
[keyboard-layout]: https://github.com/minusfive/zmk-config
[mise]: https://mise.jdx.dev
[mise-bootstrap]: https://mise.jdx.dev/bootstrap.html
[mise-dotfiles]: https://mise.jdx.dev/dotfiles.html
[nix-config]: https://github.com/minusfive/dot/tree/nix
[zsh]: https://www.zsh.org/
