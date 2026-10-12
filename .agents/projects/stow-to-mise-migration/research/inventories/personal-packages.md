# Module Inventory: `personal-packages`

## Metadata

- Module key: `personal-packages`
- Story key: `MIG-MODULE-personal-packages`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/personal-packages.md`
- Current declaration: `.config/mise/conf.d/bootstrap-packages.personal.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.personal-packages.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `none`
- Mise mode: `bootstrap package resources`
- Environment selector: `personal-packages` in the personal profile branch
- Dependencies: `MIG-MODULE-packages`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                              | Tracked | Ignored | Current owner | Current target                                           | Target disposition | New source path                                                             | New target                                            | New mode    | Notes                                                                                      |
| -------------------------------------------------------- | ------- | ------- | ------------- | -------------------------------------------------------- | ------------------ | --------------------------------------------------------------------------- | ----------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------ |
| `.config/mise/conf.d/bootstrap-packages.personal.toml:2` | `no`    | `no`    | `historical`  | `~/.config/mise/conf.d/bootstrap-packages.personal.toml` | `remove`           | `~/dev/personal/dot/home/.config/mise/conf.d/module.personal-packages.toml` | `~/.config/mise/conf.d/module.personal-packages.toml` | `bootstrap` | Retired declaration for `brew-cask:discord = "latest"`; the module source remains active.  |
| `.config/mise/conf.d/bootstrap-packages.personal.toml:3` | `no`    | `no`    | `historical`  | `~/.config/mise/conf.d/bootstrap-packages.personal.toml` | `remove`           | `~/dev/personal/dot/home/.config/mise/conf.d/module.personal-packages.toml` | `~/.config/mise/conf.d/module.personal-packages.toml` | `bootstrap` | Retired declaration for `brew-cask:softraid = "latest"`; the module source remains active. |
| `.config/mise/conf.d/bootstrap-packages.personal.toml:4` | `no`    | `no`    | `historical`  | `~/.config/mise/conf.d/bootstrap-packages.personal.toml` | `remove`           | `~/dev/personal/dot/home/.config/mise/conf.d/module.personal-packages.toml` | `~/.config/mise/conf.d/module.personal-packages.toml` | `bootstrap` | Retired declaration for `brew-cask:whatsapp = "latest"`; the module source remains active. |

## Local and runtime inventory

| Path                                                          | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                | Classification  | Required action                               | Runtime destination | Metadata to preserve                                                          | Secret or sensitive data |
| ------------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------ | --------------- | --------------------------------------------- | ------------------- | ----------------------------------------------------------------------------- | ------------------------ |
| `~/.config/mise/conf.d/bootstrap-packages.personal.toml`      | `no`   | `no`    | `no`    | `historical`     | Retired Stow link; the declaration moved to `module.personal-packages.toml`.                                       | `historical`    | `remove`                                      | `none`              | `retired declaration link`                                                    | `no`                     |
| Homebrew cask state for `discord`, `softraid`, and `whatsapp` | `no`   | `no`    | `no`    | `other`          | The personal package status reports each cask as `missing`; the declaration remains active in the personal module. | `active-global` | `apply when the personal profile is selected` | `none`              | `manager=brew-cask`; requested version `latest`; mise installation provenance | `no`                     |

No local file, credential, token, database, WAL file, cache, or tool-owned
runtime path is declared by this boundary.

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

No ignored paths are present in this boundary. The declaration is tracked, and
the package manager state is outside the repository.

## Ownership and cutover

- Current target shape: `mise-linked module declaration; package resources have no file target`
- The existing `home/.config/mise/conf.d/bootstrap-packages.personal.toml`
  is the legacy bridge source created by `MIG-MODULE-mise`; its existence does
  not complete this story. This story must rename that declaration to
  `module.personal-packages.toml` and keep the resulting module profile-only.
- Current target manifest path: `~/.config/mise/conf.d/bootstrap-packages.personal.toml`
- Old owner cleanup command: `stow -nvR .` (confirm the current declaration link before detaching it); package cleanup is separate because `mise bootstrap unapply` does not remove packages.
- New owner dry-run command: `mise -E personal,mise,packages,personal-packages bootstrap packages apply --manager brew-cask --dry-run`
- New owner apply command: `mise -E personal,mise,packages,personal-packages bootstrap packages apply --manager brew-cask --yes`
- Duplicate-owner check: `grep -R -nE '"brew-cask:(discord|softraid|whatsapp)"' .config/mise ~/dev/personal/dot/home/.config/mise`
- Target-content disposition check: `MISE_ENV=personal mise bootstrap packages status --json` and `MISE_ENV=work mise bootstrap packages status --json`; the personal result must contain all three casks and the work result must contain none.
- Relative-link check: `not applicable; this module manages package resources, not dotfile links`

## Coupling

- Scripts:
  - `scripts/init.zsh` reads and validates the persisted profile, writes it to `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile`, and exports `DOT_PROFILE`.
  - `scripts/mise.zsh` validates `DOT_PROFILE`, clears inherited
    `MISE_ENV`, then runs package `apply`, `upgrade`, and `prune`. Its current
    unqualified `mise bootstrap packages prune` uses the default `brew`
    manager, so it does not prune these casks.
  - `tests/scripts/test_mise_bootstrap_packages_personal.zsh` checks the declaration and verifies that all three casks stay out of the shared package declaration.
- Environment variables:
  - `DOT_PROFILE` selects `work` or `personal`; it defaults to `work` and is persisted outside the repository.
  - `MISE_ENV` is cleared by `scripts/mise.zsh`; `miserc.toml` selects
    `personal-packages` only in the personal branch.
- Includes or external paths:
  - `home/.config/mise/miserc.toml` and
    `home/.config/mise/conf.d/module.personal-packages.toml`; no remote include
    or external source is used.
- Other modules:
  - `packages` supplies the always-selected shared `[bootstrap.packages]` declarations. `personal-packages` is selected only by the personal profile; its execution dependency is `MIG-MODULE-packages`.
- User-facing behavior:
  - `personal` installs or updates Discord, SoftRAID, and WhatsApp as Homebrew casks. `work` does not declare them. Switching from `personal` to `work` requires a reviewed `brew-cask` prune if those casks should be removed.
  - This module reads profile-specific package status. It does not write the workspace profile targets.

## Validation

- Syntax or source checks:
  - `mise -C . config --json`
  - `git ls-files --error-unmatch home/.config/mise/conf.d/module.personal-packages.toml`
  - `zsh -n scripts/init.zsh scripts/mise.zsh`
- Focused test:
  - `zsh tests/scripts/test_mise_bootstrap_packages_personal.zsh`
- Target smoke test:
  - `mise -E personal,mise,packages,personal-packages bootstrap packages status --json`
  - `mise -E work,mise,packages bootstrap packages status --json`
- Security or token check:
  - `! grep -Eiq '(token|password|secret|credential|auth)' home/.config/mise/conf.d/module.personal-packages.toml`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-packages.personal.toml`
  - The Stow-linked target `~/.config/mise/conf.d/bootstrap-packages.personal.toml`
  - The persisted profile file at `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile`
  - Homebrew cask installation and mise provenance state
- Rollback dry run:
  - `MISE_ENV=personal mise bootstrap packages apply --manager brew-cask --dry-run`
- Rollback apply:
  - Restore the current declaration and Stow ownership, select the `personal` profile, then run `MISE_ENV=personal mise bootstrap packages apply --manager brew-cask --yes`
- Stop condition:
  - Stop if the personal declaration is absent, a package appears in both shared and personal declarations, the work profile selects any personal cask, or a prune plan proposes removing a cask still declared by a trusted configuration.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md` maps `bootstrap-packages.personal.toml` to `module.personal-packages.toml`.
  - `tests/scripts/test_mise_bootstrap_packages_personal.zsh` verifies the current three-cask declaration and shared-package separation.
- Residual risk:
  - Profile changes can make the casks undeclared. Mise's prune is manager-specific, keeps casks declared by any trusted configuration, and removes only casks mise installed and can prove unchanged. The current script does not invoke the required `--manager brew-cask` cleanup.
- Open blocker:
  - `none`
