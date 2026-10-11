# Module Inventory: `packages`

## Metadata

- Module key: `packages`
- Story key: `MIG-MODULE-packages`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/packages.md`
- Current declaration: `.config/mise/conf.d/bootstrap-packages.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.packages.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `none`
- Mise mode: `bootstrap package resources`
- Environment selector: `packages` in both profile branches
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                            | Tracked | Ignored | Current owner | Current target | Target disposition | New source path                                                             | New target | New mode                      | Notes                                                                                              |
| ------------------------------------------------------ | ------- | ------- | ------------- | -------------- | ------------------ | --------------------------------------------------------------------------- | ---------- | ----------------------------- | -------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/bootstrap-packages.toml`          | `yes`   | `no`    | `mise`        | `none`         | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/module.packages.toml`          | `none`     | `bootstrap package resources` | Shared Homebrew formulas, Homebrew casks, Mac App Store apps, and `[bootstrap.brew] adopt = true`. |
| `.config/mise/conf.d/bootstrap-packages.personal.toml` | `yes`   | `no`    | `mise`        | `none`         | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/module.personal-packages.toml` | `none`     | `bootstrap package resources` | Coupled profile-only cask additions. The personal profile selects this separate module.            |

## Package manifest

### Shared resources

The shared declaration is active for both `work` and `personal` profiles. Every
entry is pinned to `latest`.

| Package                     | Kind              | Declaration               | Profile            | Pin      |
| --------------------------- | ----------------- | ------------------------- | ------------------ | -------- |
| `brew:sqlite`               | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:bat`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:btop`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:coreutils`            | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:curl`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:dockutil`             | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:eza`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:fd`                   | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:findutils`            | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:fzf`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:gh`                   | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:ghostscript`          | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:git`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:gum`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:htop`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:imagemagick`          | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:jq`                   | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:just`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:lazygit`              | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:libtiff`              | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:libyaml`              | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:luarocks`             | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:mas`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:neovim`               | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:pkl-lsp`              | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:ripgrep`              | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:stow`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:tectonic`             | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:tmux`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:vivid`                | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:wallpaper`            | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:wget`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:yazi`                 | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:yq`                   | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:zoxide`               | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew:zsh`                  | Homebrew formula  | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:1password`       | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:1password-cli`   | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:betterdisplay`   | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:claude-code`     | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:docker-desktop`  | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:google-chrome`   | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:ghostty`         | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:gpg-suite`       | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:hammerspoon`     | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:imageoptim`      | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:obsidian`        | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `brew-cask:wezterm@nightly` | Homebrew cask     | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `mas:1497506650`            | Mac App Store app | `bootstrap-packages.toml` | `work`, `personal` | `latest` |
| `mas:1569813296`            | Mac App Store app | `bootstrap-packages.toml` | `work`, `personal` | `latest` |

The shared declaration has no `[bootstrap.brew.taps]` section. The current
test identifies `1497506650` as Yubico Authenticator and `1569813296` as
1Password for Safari. The declaration does not include `brew:mise`.

### Profile-only additions

The personal declaration adds these casks when `DOT_PROFILE=personal` selects
the `personal` mise environment. They are not duplicated in the shared
declaration.

| Package              | Kind          | Declaration                        | Profile    | Pin      |
| -------------------- | ------------- | ---------------------------------- | ---------- | -------- |
| `brew-cask:discord`  | Homebrew cask | `bootstrap-packages.personal.toml` | `personal` | `latest` |
| `brew-cask:softraid` | Homebrew cask | `bootstrap-packages.personal.toml` | `personal` | `latest` |
| `brew-cask:whatsapp` | Homebrew cask | `bootstrap-packages.personal.toml` | `personal` | `latest` |

## Local and runtime inventory

| Path                                                   | Exists    | Tracked | Ignored | Current location | Active use evidence                                                                                                               | Classification  | Required action | Runtime destination      | Metadata to preserve                                                  | Secret or sensitive data |
| ------------------------------------------------------ | --------- | ------- | ------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------- | --------------- | ------------------------ | --------------------------------------------------------------------- | ------------------------ |
| `.config/mise/conf.d/bootstrap-packages.toml`          | `yes`     | `yes`   | `no`    | `repo`           | `mise env_conf_d` loads the declaration. `scripts/mise.zsh` runs package bootstrap commands.                                      | `active-global` | `move`          | `none`                   | `TOML source. Preserve section names, package keys, and latest pins.` | `no`                     |
| `.config/mise/conf.d/bootstrap-packages.personal.toml` | `yes`     | `yes`   | `no`    | `repo`           | `mise env_conf_d` loads it for the personal profile. The personal package test asserts its casks.                                 | `active-global` | `move`          | `none`                   | `TOML source. Preserve personal-only casks and latest pins.`          | `no`                     |
| Homebrew package state                                 | `unknown` | `no`    | `no`    | `other`          | `bootstrap.packages` declares `brew:` and `brew-cask:` resources. `[bootstrap.brew] adopt = true` adopts existing Homebrew state. | `active-global` | `preserve`      | `Homebrew-managed state` | `Homebrew metadata and installed package state`                       | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/mise/conf.d
git check-ignore -v <path>
```

No package declaration contains credentials, tokens, databases, private keys,
or tool runtime state. Do not copy Homebrew or Mac App Store metadata into the
repository inventory.

## Ownership and cutover

- Current target shape: `external package state, no filesystem target`
- Current target manifest path: `.config/mise/conf.d/bootstrap-packages.toml`
- Old owner cleanup command: `mise bootstrap packages prune --dry-run`
- New owner dry-run command: `mise bootstrap packages apply --dry-run`
- New owner apply command: `mise bootstrap packages apply --yes`
- Duplicate-owner check: `grep -rhoE '"(brew|brew-cask|mas):[^"]+"' .config/mise/conf.d ~/dev/personal/dot/home/.config/mise/conf.d 2>/dev/null | sort | uniq -d`
- Target-content disposition check: `mise bootstrap packages apply --dry-run`
- Relative-link check: `not applicable, package resources do not create dotfile links`

Keep the current declaration until the replacement module is present and
selected. Because package resources have no target root, ownership validation
is a declaration and dry-run check rather than a filesystem-link check.

## Coupling

- Scripts:
  - `scripts/init.zsh` validates and persists `DOT_PROFILE`, then sources `scripts/brew.zsh` and `scripts/mise.zsh`.
  - `scripts/brew.zsh` is the optional `--brew` Homebrew installation bridge and must run before package bootstrap when Homebrew is absent.
  - `scripts/mise.zsh` validates the profile, exports `MISE_ENV`, and runs `mise bootstrap packages apply --yes`, `upgrade --yes`, and `prune --yes` in the package phase.
  - No `scripts/mise.zsh` change is required for the module rename. Its package command boundary remains `packages`.
- Environment variables:
  - `DOT_PROFILE` is written by `scripts/init.zsh` and defaults to `work`. Valid values are `work` and `personal`.
  - `MISE_ENV` is exported by `scripts/mise.zsh` from `DOT_PROFILE` and selects the mise profile environment.
- Includes or external paths:
  - `none` in the package declarations. Homebrew and Mac App Store state remain external to the repository.
- Other modules:
  - `MIG-MODULE-mise` is the direct dependency because the mise control plane and `env_conf_d` loading must exist first.
  - `MIG-MODULE-personal-packages` depends on this shared package module and must retain its separate personal-only casks.
  - `MIG-MODULE-repos` and `MIG-MODULE-tools` are later stories in the roadmap sequence.
- User-facing behavior:
  - Shared packages remain selected for both profiles. The personal profile adds Discord, Softraid, and WhatsApp casks.
  - `[bootstrap.brew] adopt = true` remains part of the shared package declaration.
  - `mise bootstrap unapply` does not remove package resources. Package cleanup requires `mise bootstrap packages prune`, and a profile change must be previewed before applying prune.
  - A direct package-module unapply or profile change does not by itself remove Homebrew formulas, casks, or Mac App Store apps. The full `scripts/mise.zsh` package phase invokes prune, but only when the mise phase is enabled.

## Validation

- Syntax or source checks:
  - `zsh -n scripts/init.zsh scripts/mise.zsh scripts/brew.zsh`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/packages.md`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_packages.zsh`
- Target smoke test:
  - `mise bootstrap packages apply --dry-run`
- Security or token check:
  - `git grep -nE 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- .agents/projects/stow-to-mise-migration/research/inventories/packages.md`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-packages.toml` and `.config/mise/conf.d/bootstrap-packages.personal.toml`. Preserve the package dry-run output before changing declarations.
- Rollback dry run:
  - Restore the old declaration files, then run `mise bootstrap packages apply --dry-run`.
- Rollback apply:
  - `mise bootstrap packages apply --yes`
- Stop condition:
  - Stop if the dry run proposes unexpected package removals, if the selected profile omits a required declaration, or if both old and new declarations claim the same package resource.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-packages.toml`
  - `.config/mise/conf.d/bootstrap-packages.personal.toml`
  - `scripts/mise.zsh`
  - `tests/scripts/test_mise_bootstrap_packages.zsh`
  - `tests/scripts/test_mise_bootstrap_packages_personal.zsh`
  - `tests/scripts/test_mise_config.zsh`
  - `.agents/projects/stow-to-mise-migration/module-registry.toml`
- Residual risk:
  - The focused shared-package test asserts adoption, two Mac App Store IDs, shared casks, exclusions, and forbidden sections, but it does not enumerate every shared formula. Package installation and prune operate on external machine state and can change installed software.
- Open blocker:
  - `none for inventory, migration execution remains pending explicit approval and a reviewed package dry run`
