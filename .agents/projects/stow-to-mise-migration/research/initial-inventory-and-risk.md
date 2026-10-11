# Initial inventory and risk assessment

**Status:** Baseline captured on 2026-10-08. No migration changes were applied.

The original cross-boundary source, target, mode, coupling, and validation
summary is preserved in the module inventories and roadmap. The current
execution-specific decisions are controlled by the roadmap, module inventories,
approval records, baseline records, and module registry. This document records
the evidence and risk assessment behind the original summary.

The counts below describe the pre-cleanup baseline. They are historical
evidence, not the current migration scope.

## Scope

This project covers the remaining migration from the Stow source tree at
`.config/` to the mise source tree at `home/`.

The current snapshot contains:

- 23 top-level entries under `.config/`.
- 329 files under `.config/`.
- 279 tracked `.config/` files.
- 180 files under `home/`.
- 118 tracked `home/` files.
- 150 tracked Hammerspoon files.
- 54 tracked Neovim files.

The counts include runtime and ignored files in the physical source trees.
The tracked counts define the current repository ownership surface.

## Current ownership model

- `.stowrc` sets `$HOME` as the Stow target.
- `scripts/symlink.zsh` applies Stow with `stow -vR .`.
- `scripts/mise.zsh` applies mise packages, files, repositories, and dotfiles
  in that order.
- `.config/mise/conf.d/bootstrap-ai.toml` already maps `home/` AI resources.
- `.config/mise/conf.d/bootstrap-gh.toml` already maps the GitHub profile and
  hosts source.
- `.stow-local-ignore` excludes current mise-owned home resources.
- `README.md` states that one target must have one owner.

The `.config/mise/` directory is the current tracked mise source tree. It
contains global mise configuration, bootstrap declarations, tasks, utilities,
and the mise lock file. Move this source tree under `home/.config/mise/` and
let mise own the target `~/.config/mise/` in the initial control-plane phase.

## Baseline command results

- `mise bootstrap dotfiles status` reports all current mise dotfiles as
  applied.
- `mise bootstrap dotfiles apply --dry-run` reports that all current files are
  applied.
- `stow -nvR .` no longer reports the deleted Copilot repository boundary.

## Security and data-safety boundaries

Do not move these paths into `home/`:

- `.config/zsh/.zsh_history`
- `.config/zsh/.zcompdump`

The Zsh history and completion dump are runtime files. They can contain
commands, paths, and sensitive arguments.

Treat `home/.config/gh/personal/hosts.yml` as credential-bearing configuration.
Keep the existing token-free invariant from
`tests/scripts/test_mise_bootstrap_gh.zsh`. Do not copy token values into
research artifacts or migration sources.

Review these paths before any ownership change:

- `.config/git/config` has conditional include paths and signing commands.
- `.config/1Password/ssh/agent.toml` names password-vault sources.
- `.config/BetterDisplay/config.plist` contains machine-specific display data.
- `.config/hammerspoon/` contains executable Lua automation.
- `.config/wezterm/wezterm.lua` loads a remote plugin and uses machine paths.

The current path scan found no reason to expose file contents in this project.
Future migration work must inspect behavior without copying secret values.

## Boundary inventory

| Boundary                | Files | Risk   | Complexity | Recommended disposition                                                       |
| ----------------------- | ----: | ------ | ---------- | ----------------------------------------------------------------------------- |
| `.config/1Password`     |     1 | Medium | Low        | Review as app-owned configuration. Migrate only after a tool-specific test.   |
| `.config/bat`           |     2 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/BetterDisplay` |     2 | Medium | Medium     | Keep in its script boundary. Preserve import and export behavior.             |
| `.config/btop`          |     2 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/delta`         |     1 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/fd`            |     1 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/fzf`           |     1 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/ghostty`       |     4 | Low    | Medium     | Migrate tracked configuration and shaders.                                    |
| `.config/git`           |     2 | Medium | Medium     | Review include targets and signing behavior before migration.                 |
| `.config/hammerspoon`   |   150 | High   | High       | Migrate as a separate executable-configuration phase.                         |
| `.config/harper`        |     1 | Medium | Low        | Treat the dictionary as personal user data. Review before migration.          |
| `.config/lazygit`       |     2 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/mise`          |    19 | High   | High       | Move under `home/.config/mise/`; mise owns target.                            |
| `.config/nvim`          |    54 | Medium | High       | Migrate as a separate editor phase. Review generated artifacts.               |
| `.config/ripgrep`       |     1 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/tmux`          |     1 | Low    | Low        | Migrate as an individual low-risk module story.                               |
| `.config/wezterm`       |    49 | Medium | Medium     | Migrate tracked runtime hooks and configuration only. Exclude research state. |
| `.config/yazi`          |    14 | Low    | Medium     | Migrate with a directory ownership test for plugins and flavors.              |
| `.config/zsh`           |     8 | High   | Medium     | Migrate source files only. Keep history and completion state outside `home/`. |

The physical file total is larger than the tracked total because several
boundaries contain ignored application state or generated research files.

## Risk assessment

### Highest risks

1. **Secret or runtime-state exposure.** A broad directory copy can include
   authentication databases, WAL files, shell history, or generated state.
2. **Dual ownership.** Stow and mise can both target the same path if the old
   source is not removed or ignored after the new source is ready.
3. **Executable configuration drift.** Hammerspoon, Zsh, WezTerm, and Neovim
   can fail at startup even when their files link successfully.
4. **Machine-specific behavior.** BetterDisplay uses display identifiers.
   Git uses conditional include paths and signing commands.
5. **Bootstrap sequencing.** New mise declarations must run after their source
   files exist and before the old Stow ownership is retired.

### Complexity drivers

- Directory size is not the only measure. Runtime exclusions and target
  coexistence determine the safe mise mode.
- `symlink-each` is a candidate for directories that contain both managed
  source files and application-owned runtime files.
- Large executable boundaries need focused tests and a rollback point.
- The current tests cover AI, GitHub, packages, repositories, mise ordering,
  and BetterDisplay. They do not yet cover every `.config` boundary.

## Ownership strategy comparison

| Strategy                                        | Benefit                                                 | Main risk                                                           | Decision  |
| ----------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------- | --------- |
| Keep Stow as the only owner until the end       | One active system during the migration                  | A large final cutover creates a wide rollback surface               | Reject    |
| Transfer ownership one boundary at a time       | Small changes, focused tests, and clear rollback points | The repository has two active systems during the transition         | Recommend |
| Copy all `.config` content into `home/` at once | Fast source-tree conversion                             | Runtime state, conflicts, and executable failures can move silently | Reject    |

The recommended strategy uses direct mise `dotfiles` entries for individual
files and `symlink-each` for directories that also contain application-owned
runtime files. It keeps the old Stow source until the new mise owner passes its
focused checks.

## Safe-path recommendation

Use an incremental migration with one owner per target:

1. Capture a non-mutating Stow and mise baseline.
2. Freeze the sensitive-path exclusion list.
3. Migrate low-risk static boundaries in one new mise declaration.
4. Migrate shell and terminal boundaries as separate units.
5. Migrate Neovim, Hammerspoon, BetterDisplay, and other executable or
   machine-specific boundaries one at a time.
6. Remove or ignore each old Stow source only after the mise dry run shows the
   intended target and focused tests pass.
7. Run the complete repository checks before closing the migration.

Do not use a single bulk move. The bulk move has a large blast radius and can
silently transfer runtime state.

## Required validation gates

Run these checks at every ownership transition:

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --dry-run
stow -nvR .
```

Run the focused boundary test before the aggregate checks. Run these checks
before the migration is complete:

```bash
mise run check
./scripts/init.zsh --mise
```

The full apply command changes the machine. Future execution requires explicit
approval for the selected migration phase before it runs.
