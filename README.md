# Personal System Configuration

This repository manages my macOS configuration. It uses [mise][mise],
[Homebrew][homebrew], and custom [Zsh][zsh] scripts.

I also maintain a [Nix-based configuration][nix-config]. I keep both
configurations aligned when their supported systems overlap.

The configuration includes keyboard shortcuts for application launchers,
window management, and text editing. These shortcuts work best with my
[custom keyboard layout][keyboard-layout].

## Setup

The initialization script changes system settings and installs software. Read
the [initialization script](./scripts/init.zsh) and the scripts that it calls
before you run it.

Clone the repository and initialize a machine:

```sh
git clone --single-branch --branch main git@github.com:minusfive/dot.git ~/dev/dot
cd ~/dev/dot
./scripts/init.zsh
```

The bootstrap supports `work` and `personal` profiles. The `work` profile is
the default and is the safer choice for a new machine.

Select a profile with `--profile`:

```sh
./scripts/init.zsh --profile personal --mise
```

The script stores the selected profile at
`${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and exports it as
`DOT_PROFILE`. Later runs use the stored profile unless you select another one.

Both profiles load the shared package set. The `personal` profile also loads
the Discord, SoftRAID, and WhatsApp casks. The selected profile controls the
active profile-specific `mise` environment.

Hammerspoon reads the same state file through the
[ProfileState Spoon](./home/.config/hammerspoon/Spoons/ProfileState.spoon/init.lua).
It mirrors the profile through `hs.settings`. The state file remains the source
of truth.

## Repository layout

The `home/` directory is a source tree for files that belong under `$HOME`.
Its layout mirrors the target layout, so each source path also describes its
installed path.

Look in these directories when you customize the configuration:

- [Hammerspoon](./home/.config/hammerspoon/)
- [Neovim](./home/.config/nvim/)
- [WezTerm](./home/.config/wezterm/)

## Mise configuration

[mise][mise] manages global files, packages, and repository tools.
Declarations for global configuration live in
[home/.config/mise/conf.d/](./home/.config/mise/conf.d/). Mise links these
files into `~/.config/mise/`.

The declarations are grouped by logical boundary. For example,
`module.gh.toml` manages GitHub resources and `module.profiles.toml` manages
rendered workspace profiles. This keeps each bootstrap area small and
independently understandable.

Package resources use dedicated module files. Tightly coupled declarations
share a module. `miserc.toml` selects the modules for each profile.

Mise uses two related resource models:

- `[dotfiles]` describes user files that mise links, copies, templates, tracks,
  or removes.
- `[bootstrap.files]` describes files that bootstrap creates or renders.
- `[bootstrap.directories]` describes directory state, such as permissions.

Read the [mise dotfiles documentation][mise-dotfiles] and the
[mise bootstrap documentation][mise-bootstrap] for resource modes and
bootstrap phases.

The `--mise` initialization interface updates mise. It then applies the
package, file, repository, and dotfile phases.

Each target belongs to one management system. For example,
[`home/.zshenv`](./home/.zshenv) belongs to `module.zsh.toml`, while
[`home/.ssh/config`](./home/.ssh/config) belongs to
[`module.1password.toml`](./home/.config/mise/conf.d/module.1password.toml).

## Development

The repository manages the tools that it uses for development. Entering the
repository activates its project-specific `mise` environment.

Run the setup task to install project dependencies and install `hk` hooks that
run through `mise`:

```sh
mise run setup
```

Run all configured checks:

```sh
mise run check
```

The [hk configuration](./hk.pkl) runs checks and fixes from one shared
definition. It uses [rumdl][rumdl] for Markdown linting and formatting.
`.rumdl.toml` keeps the previous Markdown style choices, including its
inline HTML allowlist.

![Workspace](./assets/workspace.png)

[homebrew]: https://brew.sh
[keyboard-layout]: https://github.com/minusfive/zmk-config
[mise]: https://mise.jdx.dev
[mise-bootstrap]: https://mise.jdx.dev/bootstrap.html
[mise-dotfiles]: https://mise.jdx.dev/dotfiles.html
[nix-config]: https://github.com/minusfive/dot/tree/nix
[rumdl]: https://rumdl.dev
[zsh]: https://www.zsh.org/
