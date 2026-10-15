# Personal System Configuration

This repository manages my `macOS` settings. It uses [`mise`][mise] and custom [`Zsh`][zsh] scripts.

The configuration includes keyboard shortcuts for launching apps, managing windows, and editing text. These shortcuts work best with my [custom keyboard layout][keyboard-layout].

![Workspace](./assets/workspace.png)

## Machine setup

The initialization script changes system settings and installs software. Read the [initialization script](./scripts/init.zsh) and the scripts that it calls before you run it.

Clone the repository and initialize a machine:

```bash
git clone --single-branch --branch main git@github.com:minusfive/dot.git ~/dev/personal/dot
cd ~/dev/personal/dot
./scripts/init.zsh --mise
```

### Bootstrapped with `mise`

The `--mise` option starts setup with `mise` on a new machine.

[`mise`][mise] manages global files, packages, and repository tools. Its global configuration files live in [home/.config/mise/conf.d/](./home/.config/mise/conf.d/). `mise` links these files into `~/.config/mise/`.

The files are grouped by purpose. Each module manages related resources. A `dotfiles` entry can manage a whole file or selected configuration values. This keeps each setup area small and easier to understand.

Package lists use separate module files. Related declarations share a module. `miserc.toml` selects the modules for each profile.

[`dotfiles`][mise-dotfiles] entries tell `mise` how to manage user files. It can link, copy, create from templates, track, or remove them. [`bootstrap.files`][mise-bootstrap] entries create or render files during setup. [`bootstrap.directories`][mise-bootstrap] entries set directory properties, such as permissions. Together, these entries describe what setup manages and when it manages it.

### `Homebrew`

[`Homebrew`][homebrew] is optional because `mise` installs the listed packages directly. It can be installed by running `./scripts/init.zsh --brew`.

### Profiles

The `work` profile is the default and excludes personal-only tools and applications. To apply the `personal` profile, run:

```bash
./scripts/init.zsh --profile personal --mise
```

The script saves the selected profile at `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and exports it as `DOT_PROFILE`. Later runs use the saved profile unless a different one is selected.

Each profile loads a different group of `mise` modules. These modules list the files and tools for that profile.

[`Hammerspoon`](./home/.config/hammerspoon/) reads the same state file through the [`ProfileState Spoon`](./home/.config/hammerspoon/Spoons/ProfileState.spoon/init.lua) so it can customize keyboard shortcuts and other automations for the selected profile. The `hs.settings` interface stores the profile in `macOS` defaults under a custom key, so other applications can read it.

### File ownership and application data

The `home/` tree contains files owned by this repository. `mise` places selected files where the corresponding tool or application expects to find them, including `mise` itself. A placed file is not a second copy of the source. When a tool edits a linked file, it edits the repository file.

`mise` supports several ways to place files:

- A `symlink` links one file directly to the repository. Edits at the installed path change the repository file and appear as repository changes.
- `symlink-each` gives a directory a real target and links each file found in the source directory. It does not copy files that exist only at the target. By default, it reads the source directory instead of the list of files tracked by `Git`. Repository-only files need explicit exclusions because the source directory is scanned by default. A manifest lists tracked files and limits the target to those files.
- A template dynamically creates target output from a shared source and the current profile or machine settings. Edits to the output do not change the source. A profile-specific merge template can update selected values in an application-owned file without moving that file into the source tree.

The granular `symlink` approach allows other generated files (such as histories, caches, databases, credentials, etc.), to stay outside this repository, in their original location. This prevents accidental check-ins of sensitive data, and preserves application-managed permissions and cleanup.

Repository-only guidance or maintenance files can stay co-located with managed files without placing them at installed locations.

Edits made by external tools to managed files appear as repository changes. Those changes are then checked by hooks, and reviewed by agents and myself, before every commit.

The `--mise` option runs all `mise` setup steps. It asks for approval once before it updates `mise` itself, places files, installs tools and applications, clones repositories, runs scripts, and performs maintenance such as updates and cleanup.

### Global agent instructions and skills

The repository keeps global agent instructions and skills in `home/`. `home/AGENTS.md` and `home/.agents/skills/` are source files. The `mise` agents module manages these sources like any other module. Harness-specific modules symlink the same files to each harness's global instruction and skill locations. This keeps one source of truth while allowing each harness to use its own paths.

The root `AGENTS.md` and `.agents/` directory are repository-only. They guide work in this repository and are not deployed as global files.

`mise` tasks keep the root and `home/` skill indexes synchronized. They validate the global skill evaluation files and check for name conflicts between repository-only and global skills. The `hk` check and pre-commit hooks run these validations with the other repository checks.

## Repository layout

The `home/` directory contains files that belong under `$HOME`. Its layout matches the installed layout, so each source path also shows where the file is installed.

```text
.
├── .agents/                         # repository-only guidance, skills, and evaluation files
├── AGENTS.md                        # repository instructions
├── .mise/                           # repository-local tools and tasks
├── assets/                          # images
├── home/                            # files mirrored under ~/
│   ├── .agents/
│   │   └── skills/                  # global agent skills
│   ├── .config/
│   │   ├── 1Password/
│   │   ├── BetterDisplay/
│   │   ├── ...
│   │   └── mise/
│   │       ├── conf.d/              # per-tool module files
│   │       │   ├── module.1password.toml
│   │       │   ├── module.agents.toml
│   │       │   ├── module.bat.toml
│   │       │   └── ...
│   │       ├── config.toml
│   │       ├── mise.lock
│   │       ├── miserc.toml
│   │       ├── tasks/
│   │       └── utils/
│   ├── .ssh/
│   │   └── config                   # ~/.ssh/config
│   └── AGENTS.md                    # global agent instructions
├── scripts/                         # setup and development tasks
├── tests/                           # script tests
└── ...
```

## Development

The repository manages the tools used for development. When you enter the repository, `mise` activates its project tools.

Run the setup task to install project dependencies and add automatic `hk` checks to `mise`:

```sh
mise run setup
```

Run all configured checks:

```sh
mise run check
```

The [`hk` configuration](./hk.pkl) defines the checks and fixes in one place. Markdown checks preserve the existing line wrapping and reformat paragraphs that use hard line breaks. The repository also permits selected inline HTML.

## Previous `Nix` configuration

I previously maintained a configuration based on [`Nix`][nix-config]. I no longer maintain it because `mise` now provides many of the features I used from `Nix`.

[homebrew]: https://brew.sh
[keyboard-layout]: https://github.com/minusfive/zmk-config
[mise]: https://mise.jdx.dev
[mise-bootstrap]: https://mise.jdx.dev/bootstrap.html
[mise-dotfiles]: https://mise.jdx.dev/dotfiles.html
[nix-config]: https://github.com/minusfive/dot/tree/nix
[zsh]: https://www.zsh.org/
