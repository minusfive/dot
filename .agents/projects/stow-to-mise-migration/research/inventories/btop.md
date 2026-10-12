# Module Inventory: `btop`

## Metadata

- Module key: `btop`
- Story key: `MIG-MODULE-btop`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/btop.md`
- Current declaration: `.stowrc` (`--target=~`) with `.config/btop` as a repository-root Stow source, applied by `scripts/symlink.zsh`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.btop.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/btop`
- Mise mode: `symlink-each`
- Environment selector: `btop`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                  | Tracked | Ignored | Current owner | Current target                                 | Target disposition | New source path                                                      | New target                                     | New mode       | Notes                                                                  |
| -------------------------------------------- | ------- | ------- | ------------- | ---------------------------------------------- | ------------------ | -------------------------------------------------------------------- | ---------------------------------------------- | -------------- | ---------------------------------------------------------------------- |
| `.config/btop/btop.conf`                     | `yes`   | `no`    | `stow`        | `~/.config/btop/btop.conf`                     | `migrate`          | `~/dev/personal/dot/home/.config/btop/btop.conf`                     | `~/.config/btop/btop.conf`                     | `symlink-each` | Active btop configuration; selects the Catppuccin Mocha theme.         |
| `.config/btop/themes/catppuccin_mocha.theme` | `yes`   | `no`    | `stow`        | `~/.config/btop/themes/catppuccin_mocha.theme` | `migrate`          | `~/dev/personal/dot/home/.config/btop/themes/catppuccin_mocha.theme` | `~/.config/btop/themes/catppuccin_mocha.theme` | `symlink-each` | Active public theme source; keep the existing filename and theme name. |

## Local and runtime inventory

| Path                                         | Exists | Tracked | Ignored | Current location | Active use evidence                                                                        | Classification  | Required action | Runtime destination                            | Metadata to preserve                                 | Secret or sensitive data |
| -------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------ | --------------- | --------------- | ---------------------------------------------- | ---------------------------------------------------- | ------------------------ |
| `.config/btop/btop.conf`                     | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; the file moved to `home/.config/btop/btop.conf`.                      | `historical`    | `remove`        | `~/.config/btop/btop.conf`                     | `retired source path`                                | `no`                     |
| `.config/btop/themes/catppuccin_mocha.theme` | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; the theme moved to `home/.config/btop/themes/catppuccin_mocha.theme`. | `historical`    | `remove`        | `~/.config/btop/themes/catppuccin_mocha.theme` | `retired source path`                                | `no`                     |
| `~/.config/btop`                             | `yes`  | `no`    | `no`    | `target`         | Physical directory with two relative per-file links to the mise source.                    | `active-global` | `preserve`      | `~/.config/btop`                               | `Physical directory, owner villalj:staff, mode 0755` | `no`                     |

The source boundary contains no ignored files, no non-ignored untracked files,
and no target-only files. The target child paths are not independent files;
they resolve through the parent Stow symlink.

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/btop
# no output
git check-ignore -v .config/btop/btop.conf .config/btop/themes/catppuccin_mocha.theme
# no output
git ls-files --others --exclude-standard -- .config/btop
# no output
```

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links`
- Current target manifest path: `~/.config/btop`; managed files resolve to
  `home/.config/btop`.
- Old owner cleanup command: `stow -nvR .`; after the dry run confirms the expected link, run `test -L "$HOME/.config/btop" && test "$(readlink "$HOME/.config/btop")" = "../dev/personal/dot/.config/btop" && unlink "$HOME/.config/btop"`
- New owner dry-run command: `mise -C . -E btop dot apply --dry-run ~/.config/btop`
- New owner apply command: `mise -C . -E btop dot apply --yes ~/.config/btop`
- Duplicate-owner check: `if stow -nvR . 2>&1 | grep -F -- '.config/btop'; then exit 1; fi`
- Target-content disposition check: `target="${XDG_CONFIG_HOME:-$HOME/.config}/btop"; source="$HOME/dev/personal/dot/home/.config/btop"; test -f "$target/btop.conf" && test -f "$target/themes/catppuccin_mocha.theme"; comm -23 <(find -H "$target" -type f -print | sed "s#^$target/##" | sort) <(find "$source" -type f -print | sed "s#^$source/##" | sort)`; the `comm` result must be empty.
- Relative-link check: `for path in ~/.config/btop/btop.conf ~/.config/btop/themes/catppuccin_mocha.theme; do test -L "$path" || exit 1; case "$(readlink "$path")" in /*) exit 1;; esac; done; test "$(realpath ~/.config/btop/btop.conf)" = "$HOME/dev/personal/dot/home/.config/btop/btop.conf"; test "$(realpath ~/.config/btop/themes/catppuccin_mocha.theme)" = "$HOME/dev/personal/dot/home/.config/btop/themes/catppuccin_mocha.theme"`

## Coupling

- Scripts:
  - `scripts/zsh.zsh` updates the btop theme at line 99 when `btop` is installed. Before the ownership cutover, the destination is `$XDG_CONFIG_HOME/btop/themes/catppuccin_mocha.theme`; update it to `"$__dotfiles_root/home/.config/btop/themes/catppuccin_mocha.theme"` so the public download writes to the tracked source, not the deployed target.
  - `scripts/symlink.zsh` currently runs `stow -vR .` and creates the whole-directory target link; it must not recreate `~/.config/btop` after the Stow source is retired.
  - `scripts/mise.zsh` already runs `mise bootstrap dotfiles apply --yes` after package, file, repository, and tool work; no new initialization phase is required.
- Environment variables:
  - `XDG_CONFIG_HOME` currently identifies the deployed target used by the theme download. The migrated download must use the repository root held by `__dotfiles_dir`; btop itself uses the standard `$HOME/.config/btop` target. `MISE_ENV=btop` or `mise -E btop` selects the module environment.
- Includes or external paths:
  - `btop.conf` uses btop's implicit `$HOME/.config/btop/themes` lookup and has no file includes. `scripts/zsh.zsh` downloads the public theme from `https://github.com/catppuccin/btop/raw/main/themes/catppuccin_mocha.theme`.
- Other modules:
  - `MIG-MODULE-mise` is the control-plane dependency. `.config/mise/conf.d/bootstrap-packages.toml` separately installs `brew:btop`; package installation is not a source ownership dependency.
- User-facing behavior:
  - Preserve the current btop configuration, Catppuccin Mocha theme, and theme refresh behavior. Do not download or modify the theme during inventory work.

## Validation

- Syntax or source checks:
  - `git ls-files -- home/.config/btop` must list exactly `btop.conf` and `themes/catppuccin_mocha.theme`.
  - `git ls-files --others --ignored --exclude-standard -- home/.config/btop` and `git ls-files --others --exclude-standard -- home/.config/btop` must produce no output.
  - After staging the new source, `test -f ~/dev/personal/dot/home/.config/btop/btop.conf && test -f ~/dev/personal/dot/home/.config/btop/themes/catppuccin_mocha.theme && grep -Fq 'color_theme = "catppuccin_mocha"' ~/dev/personal/dot/home/.config/btop/btop.conf`.
  - `zsh -n scripts/zsh.zsh` must pass after the download destination is changed.
- Focused test:
  - `tests/scripts/test_mise_bootstrap_btop.zsh` is planned and is not present
    in the current snapshot; add it as part of this module migration.
- Target smoke test:
  - `mise -C . -E btop dot status ~/.config/btop` and `btop --help >/dev/null`. A full interactive TUI smoke test is deferred because this inventory runs non-interactively.
- Security or token check:
  - `git grep -nEi '(token|password|secret|private[_-]?key)' -- home/.config/btop` must return no matches. Do not print theme or configuration contents beyond non-sensitive validation output.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - Save `git ls-files -- .config/btop`, `readlink ~/.config/btop`, and `find -H ~/.config/btop -print | sort`. Keep the old `.config/btop` source until the mise owner passes its focused checks.
- Rollback dry run:
  - `mise -C . -E btop dot unapply --dry-run ~/.config/btop`
- Rollback apply:
  - `mise -C . -E btop dot unapply --yes ~/.config/btop`; after the target is absent, restore the prior link with `ln -s ../dev/personal/dot/.config/btop ~/.config/btop`.
- Stop condition:
  - Stop before detaching Stow if the target is not the recorded relative symlink, contains unmanaged or target-only files, or the mise dry run names a target outside `~/.config/btop` or a source outside `~/dev/personal/dot/home/.config/btop`.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md` defines `module.btop.toml`, the two source files, `symlink-each`, the static sequence, and the theme-source coupling.
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `MIG-MODULE-btop` and its dependency on `MIG-MODULE-mise`.
  - `git ls-files -- .config/btop` found two tracked files; the ignored and untracked-file checks returned no paths.
  - `~/.config/btop` is the expected whole-directory Stow symlink to `.config/btop`.
- Residual risk:
  - The current `scripts/zsh.zsh` download writes through the Stow target into the repository. It must be redirected to the new `~/dev/personal/dot/home/.config/btop` source before the old symlink is detached. The public download remains mutable custom network code.
- Open blocker:
  - None. The target now uses the approved mise `symlink-each` declaration and
    the theme source points to the home source tree.
