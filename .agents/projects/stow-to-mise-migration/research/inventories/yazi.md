# Module Inventory: `yazi`

## Metadata

- Module key: `yazi`
- Story key: `MIG-MODULE-yazi`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/yazi.md`
- Current declaration: `.stowrc` (`--target=~`) and `scripts/symlink.zsh` (`stow -vR .`)
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.yazi.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/yazi`
- Mise mode: `symlink-each`
- Environment selector: `yazi` in both profile branches
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                                  | Tracked | Ignored | Current owner | Current target                                                 | Target disposition | New source path                                                                      | New target                                                     | New mode       | Notes                                                                                                                                                                                          |
| ------------------------------------------------------------ | ------- | ------- | ------------- | -------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------ | -------------------------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE`         | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE`         | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE`         | `~/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE`         | `symlink-each` | Tracked flavor license.                                                                                                                                                                        |
| `.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE-tmtheme` | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE-tmtheme` | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE-tmtheme` | `~/.config/yazi/flavors/catppuccin-mocha.yazi/LICENSE-tmtheme` | `symlink-each` | Tracked tmTheme license.                                                                                                                                                                       |
| `.config/yazi/flavors/catppuccin-mocha.yazi/README.md`       | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/README.md`       | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/README.md`       | `~/.config/yazi/flavors/catppuccin-mocha.yazi/README.md`       | `symlink-each` | Tracked flavor documentation and usage reference.                                                                                                                                              |
| `.config/yazi/flavors/catppuccin-mocha.yazi/flavor.toml`     | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/flavor.toml`     | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/flavor.toml`     | `~/.config/yazi/flavors/catppuccin-mocha.yazi/flavor.toml`     | `symlink-each` | Catppuccin Mocha flavor source; selected by `theme.toml`.                                                                                                                                      |
| `.config/yazi/flavors/catppuccin-mocha.yazi/preview.png`     | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/preview.png`     | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/preview.png`     | `~/.config/yazi/flavors/catppuccin-mocha.yazi/preview.png`     | `symlink-each` | Tracked flavor preview asset.                                                                                                                                                                  |
| `.config/yazi/flavors/catppuccin-mocha.yazi/tmtheme.xml`     | `yes`   | `no`    | `Stow`        | `~/.config/yazi/flavors/catppuccin-mocha.yazi/tmtheme.xml`     | `migrate`          | `~/dev/personal/dot/home/.config/yazi/flavors/catppuccin-mocha.yazi/tmtheme.xml`     | `~/.config/yazi/flavors/catppuccin-mocha.yazi/tmtheme.xml`     | `symlink-each` | Tracked tmTheme asset.                                                                                                                                                                         |
| `.config/yazi/init.lua`                                      | `yes`   | `no`    | `Stow`        | `~/.config/yazi/init.lua`                                      | `migrate`          | `~/dev/personal/dot/home/.config/yazi/init.lua`                                      | `~/.config/yazi/init.lua`                                      | `symlink-each` | Loads the pinned `no-status` plugin.                                                                                                                                                           |
| `.config/yazi/keymap.toml`                                   | `yes`   | `no`    | `Stow`        | `~/.config/yazi/keymap.toml`                                   | `migrate`          | `~/dev/personal/dot/home/.config/yazi/keymap.toml`                                   | `~/.config/yazi/keymap.toml`                                   | `symlink-each` | Tracked empty keymap configuration; preserve the file.                                                                                                                                         |
| `.config/yazi/package.toml`                                  | `yes`   | `no`    | `Stow`        | `~/.config/yazi/package.toml`                                  | `migrate`          | `~/dev/personal/dot/home/.config/yazi/package.toml`                                  | `~/.config/yazi/package.toml`                                  | `symlink-each` | Pins `yazi-rs/plugins:no-status` at rev `3d0c7c6`, hash `513a23ac28e1eaa626f3a1bb6c8130d0`; pins `yazi-rs/flavors:catppuccin-mocha` at rev `c023460`, hash `2ac87e1b3a61f5887472899e86535d29`. |
| `.config/yazi/plugins/no-status.yazi/LICENSE`                | `yes`   | `no`    | `Stow`        | `~/.config/yazi/plugins/no-status.yazi/LICENSE`                | `migrate`          | `~/dev/personal/dot/home/.config/yazi/plugins/no-status.yazi/LICENSE`                | `~/.config/yazi/plugins/no-status.yazi/LICENSE`                | `symlink-each` | Tracked plugin license.                                                                                                                                                                        |
| `.config/yazi/plugins/no-status.yazi/README.md`              | `yes`   | `no`    | `Stow`        | `~/.config/yazi/plugins/no-status.yazi/README.md`              | `migrate`          | `~/dev/personal/dot/home/.config/yazi/plugins/no-status.yazi/README.md`              | `~/.config/yazi/plugins/no-status.yazi/README.md`              | `symlink-each` | Tracked plugin documentation and usage reference.                                                                                                                                              |
| `.config/yazi/plugins/no-status.yazi/main.lua`               | `yes`   | `no`    | `Stow`        | `~/.config/yazi/plugins/no-status.yazi/main.lua`               | `migrate`          | `~/dev/personal/dot/home/.config/yazi/plugins/no-status.yazi/main.lua`               | `~/.config/yazi/plugins/no-status.yazi/main.lua`               | `symlink-each` | Pinned `no-status` plugin implementation loaded by `init.lua`.                                                                                                                                 |
| `.config/yazi/theme.toml`                                    | `yes`   | `no`    | `Stow`        | `~/.config/yazi/theme.toml`                                    | `migrate`          | `~/dev/personal/dot/home/.config/yazi/theme.toml`                                    | `~/.config/yazi/theme.toml`                                    | `symlink-each` | Selects the `catppuccin-mocha` flavor and preserves status styling overrides.                                                                                                                  |
| `.config/yazi/yazi.toml`                                     | `yes`   | `no`    | `Stow`        | `~/.config/yazi/yazi.toml`                                     | `migrate`          | `~/dev/personal/dot/home/.config/yazi/yazi.toml`                                     | `~/.config/yazi/yazi.toml`                                     | `symlink-each` | Preserves hidden-file display, natural sorting, and size linemode.                                                                                                                             |

The 14 rows above are the complete output of `git ls-files -- .config/yazi/`.
`git ls-files --others --ignored --exclude-standard -- .config/yazi` and
`git ls-files --others --exclude-standard -- .config/yazi` returned no paths.
Because no ignored or untracked candidate exists, there is no applicable
`git check-ignore -v <path>` result.

## Local and runtime inventory

| Path             | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                | Classification   | Required action | Runtime destination | Metadata to preserve                   | Secret or sensitive data |
| ---------------- | ------ | ------- | ------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | --------------- | ------------------- | -------------------------------------- | ------------------------ |
| `~/.config/yazi` | `yes`  | `no`    | `no`    | `target`         | Physical directory with 14 relative per-file links; `yazi --version` and `ya --version` are available                                              | `active-global`  | `preserve`      | `~/.config/yazi`    | Physical directory with relative links | `no`                     |
| `<none>`         | `no`   | `no`    | `no`    | `repo`           | Both `git ls-files --others --ignored --exclude-standard -- .config/yazi` and `git ls-files --others --exclude-standard -- .config/yazi` are empty | `not-applicable` | `none`          | `none`              | `none`                                 | `no`                     |

No ignored, untracked, generated, credential-bearing, or tool-runtime path
was found inside the `.config/yazi` source boundary.

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/yazi
git check-ignore -v <path>
```

No ignored path exists, so `git check-ignore -v <path>` has no applicable
argument.

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links`
- Current target manifest path: `~/.config/yazi`
- Old owner cleanup command: `[[ -L "$HOME/.config/yazi" && "$(readlink "$HOME/.config/yazi")" == "../dev/personal/dot/.config/yazi" ]] && rm "$HOME/.config/yazi"`
- New owner dry-run command: `mise dot apply --dry-run ~/.config/yazi`
- New owner apply command: `mise dot apply ~/.config/yazi`
- Duplicate-owner check: `stow -nvR . 2>&1 | grep -F '.config/yazi'` (must return no yazi ownership after cutover)
- Target-content disposition check: `ls -lad "$HOME/.config/yazi"; find -H "$HOME/.config/yazi" -mindepth 1 -maxdepth 3 -print`
- Relative-link check: `! find "$HOME/.config/yazi" -type l -exec readlink {} \; | grep -q '^/'`

## Coupling

- Scripts:
  - `scripts/symlink.zsh` currently applies the whole repository with `stow -vR .`; it must no longer own `.config/yazi` after cutover.
  - `scripts/mise.zsh` already applies `mise bootstrap dotfiles apply --yes`; no new yazi-specific phase is required.
- Environment variables:
  - `.zshenv` sets `XDG_CONFIG_HOME="$HOME/.config"`, which defines the target root.
  - The new declaration is selected as the `yazi` mise environment and depends on the mise control-plane module.
- Includes or external paths:
  - `init.lua` loads the local `no-status` plugin; `theme.toml` loads the local `catppuccin-mocha` flavor.
  - `package.toml` contains the two upstream package identifiers with committed revision and content-hash pins; no absolute or machine-local include path is used.
- Other modules:
  - `MIG-MODULE-mise` must establish the mise control plane before the yazi declaration can be selected.
- User-facing behavior:
  - Keep Yazi showing hidden files, sorting naturally, displaying size linemode, using the Catppuccin Mocha flavor, and hiding the status bar through the pinned plugin.

## Validation

- Syntax or source checks:
  - `git ls-files -- home/.config/yazi/` must match the 14-path manifest above.
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/yazi.md`
  - `yazi --version` and `ya --version`
- Focused test:
  - `./tests/scripts/test_mise_bootstrap_yazi.zsh` (planned
    module test; it must assert the Yazi source manifest,
    `symlink-each` declaration, and package revision/hash pins).
- Target smoke test:
  - Run `yazi` interactively after cutover and verify hidden files, natural sorting, size linemode, Catppuccin Mocha styling, and the absent status bar. The interactive portion is deferred because it cannot be validated non-interactively.
- Security or token check:
  - `rg -l -i '(api[_-]?key|access[_-]?token|password[[:space:]]*=|secret[[:space:]]*=|private[_-]?key|credential[[:space:]]*=|auth\.db)' home/.config/yazi` must return no paths; do not print file contents.
  - `git ls-files --others --ignored --exclude-standard -- home/.config/yazi` must remain empty.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - Save `git ls-files -- .config/yazi/` and `readlink "$HOME/.config/yazi"`; preserve the current `~/.config/yazi` symlink until the scoped mise dry run passes.
- Rollback dry run:
  - `mise dot unapply --dry-run ~/.config/yazi`
- Rollback apply:
  - `mise dot unapply ~/.config/yazi` followed by `rmdir "$HOME/.config/yazi" && ln -s "../dev/personal/dot/.config/yazi" "$HOME/.config/yazi"` after the empty-target check passes.
- Stop condition:
  - Stop on any unexpected source or target, physical or unmanaged target content, changed package revision/hash, absolute deployed link, missing flavor/plugin, or failed Yazi smoke test.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`
    defines `.config/yazi` as a tracked-file boundary with `symlink-each` mode
    in this module story.
  - `git ls-files -- .config/yazi/` returned 14 tracked paths; ignored and untracked scans returned no paths.
  - `readlink ~/.config/yazi` returned `../dev/personal/dot/.config/yazi`, confirming the current Stow whole-directory link.
  - `.config/yazi/package.toml` records both required revision and hash pins.
- Residual risk:
  - Yazi package and configuration compatibility is version-sensitive; the current target is a whole-directory Stow link and must be detached before per-file mise links are applied.
- Open blocker:
  - None. The target now uses the approved mise `symlink-each` declaration and
    package pins remain unchanged.
