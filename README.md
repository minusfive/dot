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

### Bootstrapped with [`mise`][mise] and [`gh`][github-cli]

The `--mise` option runs all `mise` setup steps. It asks for approval once before it updates `mise` itself, `macOS` preferences, places files; installs tools, applications, and themes; clones repositories, runs scripts, and performs maintenance such as updates and cleanup.

`gh` is used to download certain files from GitHub repositories as part of the bootstrap process. When no existing `gh` session is available, a browser-based authentication flow is triggered and configures `Git` credentials for authenticated resource downloads.

### Profiles

The `work` profile is the default and excludes personal-only tools and applications. To apply the `personal` profile, run:

```bash
./scripts/init.zsh --profile personal --mise
```

The script saves the selected profile at `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and exports it as `DOT_PROFILE`. Later runs use the saved profile unless a different one is selected.

Each profile loads a different group of `mise` modules. These modules list the files and tools for that profile.

[`Hammerspoon`](./home/.config/hammerspoon/) reads the same state file through the [`ProfileState Spoon`](./home/.config/hammerspoon/Spoons/ProfileState.spoon/init.lua) so it can customize keyboard shortcuts and other automations for the selected profile. The `hs.settings` interface stores the profile in `macOS` defaults under a custom key, so other applications can read it.

### File ownership and application data

The `home/` directory mirrors the target user's `$HOME` layout. `mise` places selected files where the corresponding tool or application expects to find them, including `mise` itself. A placed file is not a second copy of the source. When a tool edits a linked file, it edits the repository file.

The [`dotfiles`][mise-dotfiles], [`bootstrap.files`][mise-bootstrap], and [`bootstrap.directories`][mise-bootstrap] entries describe how and when `mise` manages files and directories.

`mise` supports several ways to define how files are managed. This repository primarily uses the following types:

- A `symlink` links one file directly to the repository. Edits at the installed path change the repository file and appear as repository changes. Edits made by external tools to linked files appear as repository changes. Those changes are then checked by hooks, and reviewed by agents and myself, before every commit.
- `symlink-each` links every file that it finds in a source directory. It does not copy files that exist only at the target. Repository-only files need explicit exclusions.
- A `template` dynamically creates a target output file from a source file and arbitrary inputs. Edits to the output do not change the source.
- A `merge` can update specific entries or values in a target file without managing the whole file. Combined with `template` those values can be dynamically rendered from other inputs.

This granular file management approach means other generated files or values such as histories, caches, databases, credentials, etc., stay in their original location, outside this repository. This prevents accidental check-ins of sensitive data, and preserves application-managed permissions and cleanup.

The files are grouped by purpose. Each module manages related resources. A `dotfiles` entry can manage a whole file or selected configuration values. This keeps each setup area small and easier to understand. Repository-only guidance or maintenance files can stay co-located with managed files without polluting target locations.

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

#### Global agent instructions and skills

The repository keeps global agent instructions and skills in `home/`. `home/AGENTS.md` and `home/.agents/skills/` are source files. The `mise` agents module manages these sources like any other module. Harness-specific modules symlink the same files to each harness's global instruction and skill locations. This keeps one source of truth while allowing each harness to use its own paths.

The root `AGENTS.md` and `.agents/` directory are repository-only. They guide work in this repository and are not deployed as global files.

`mise` tasks keep the root and `home/` skill indexes synchronized. They validate the global skill evaluation files and check for name conflicts between repository-only and global skills. The `hk` check and pre-commit hooks run these validations with the other repository checks.

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

[github-cli]: https://cli.github.com/
[keyboard-layout]: https://github.com/minusfive/zmk-config
[mise]: https://mise.jdx.dev
[mise-bootstrap]: https://mise.jdx.dev/bootstrap.html
[mise-dotfiles]: https://mise.jdx.dev/dotfiles.html
[nix-config]: https://github.com/minusfive/dot/tree/nix
[zsh]: https://www.zsh.org/
