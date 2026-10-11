# Module Inventory: `delta`

## Metadata

- Module key: `delta`
- Story key: `MIG-MODULE-delta`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/delta.md`
- Current declaration: `.stowrc` (`--target=~`), applied by `scripts/symlink.zsh`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.delta.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/delta`
- Mise mode: `symlink-each`
- Environment selector: `delta`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                 | Tracked | Ignored | Current owner | Current target                                | Target disposition | New source path                                                     | New target                                    | New mode       | Notes                                                                                       |
| ------------------------------------------- | ------- | ------- | ------------- | --------------------------------------------- | ------------------ | ------------------------------------------------------------------- | --------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------- |
| `.config/delta/themes/catppuccin.gitconfig` | `yes`   | `no`    | `stow`        | `~/.config/delta/themes/catppuccin.gitconfig` | `migrate`          | `~/dev/personal/dot/home/.config/delta/themes/catppuccin.gitconfig` | `~/.config/delta/themes/catppuccin.gitconfig` | `symlink-each` | The only tracked source file. No ignored or non-ignored untracked source files are present. |

## Local and runtime inventory

| Path                                        | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                   | Classification   | Required action | Runtime destination                           | Metadata to preserve                                                                                      | Secret or sensitive data |
| ------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | --------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/delta/themes/catppuccin.gitconfig` | `yes`  | `yes`   | `no`    | `repo`           | `.config/git/config` includes `~/.config/delta/themes/catppuccin.gitconfig`. The current target resolves to this source.              | `active-global`  | `move`          | `~/.config/delta/themes/catppuccin.gitconfig` | Regular file. Preserve mode `0644`, owner, group, and permissions.                                        | `no`                     |
| `~/.config/delta`                           | `yes`  | `no`    | `no`    | `target`         | `readlink` reports `../dev/personal/dot/.config/delta`. The target contains the same one file as the source, and the checksums match. | `active-global`  | `preserve`      | `~/.config/delta`                             | Detach the whole-directory symlink before creating the mise-managed physical directory and per-file link. | `no`                     |
| `~/.config/delta/<target-only>`             | `no`   | `no`    | `no`    | `target`         | The target file list matches the source file list. No target-only files were found.                                                   | `not-applicable` | `none`          | `none`                                        | `none`                                                                                                    | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/delta
git check-ignore -v <path>
```

The tracked manifest is `.config/delta/themes/catppuccin.gitconfig`. The
ignored-file query and the non-ignored untracked-file query both returned no
paths. The current target is a whole-directory Stow symlink, so it exposes no
additional target-only files. Do not download or modify the Catppuccin theme
during this inventory or its validation.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/delta -> ../dev/personal/dot/.config/delta`. No separate target manifest exists.
- Old owner cleanup command: `test -L "$HOME/.config/delta" && test "$(readlink "$HOME/.config/delta")" = "../dev/personal/dot/.config/delta" && rm "$HOME/.config/delta"`
- New owner dry-run command: `mise -E delta dot apply --dry-run ~/.config/delta`
- New owner apply command: `mise -E delta dot apply ~/.config/delta`
- Duplicate-owner check: `test ! -e .config/delta && ! stow -nvR . 2>&1 | grep -F '.config/delta' && mise -E delta dot status ~/.config/delta`
- Target-content disposition check: `test -d "$HOME/.config/delta" && test ! -L "$HOME/.config/delta" && test -L "$HOME/.config/delta/themes/catppuccin.gitconfig" && test "$(realpath "$HOME/.config/delta/themes/catppuccin.gitconfig")" = "$(realpath "$HOME/dev/personal/dot/home/.config/delta/themes/catppuccin.gitconfig")"`
- Relative-link check: `link="$(readlink "$HOME/.config/delta/themes/catppuccin.gitconfig")" && test "${link#/}" = "$link" && test "$(realpath "$HOME/.config/delta/themes/catppuccin.gitconfig")" = "$(realpath "$HOME/dev/personal/dot/home/.config/delta/themes/catppuccin.gitconfig")"`

The baseline `stow -nvR .` reports `UNLINK: .config/delta` followed by
`LINK: .config/delta => ../dev/personal/dot/.config/delta`, confirming the
current Stow ownership. Remove only the confirmed whole-directory symlink
after the new source exists and the mise dry run names the intended target.

## Coupling

- Scripts:
  - `scripts/zsh.zsh:106-113` checks for `delta` and runs `wget -O "$XDG_CONFIG_HOME/delta/themes/catppuccin.gitconfig"` against the Catppuccin download URL. Do not run this update during migration research or validation. After migration, the target path resolves to the tracked `~/dev/personal/dot/home/.config` source. This command can write through the symlink and mutate the tracked theme.
- Environment variables:
  - `XDG_CONFIG_HOME` supplies the target configuration root used by `scripts/zsh.zsh`. The expected delta target is `~/.config/delta`.
- Includes or external paths:
  - `.config/git/config` sets `core.pager = delta`, `interactive.diffFilter = delta --color-only`, and includes `~/.config/delta/themes/catppuccin.gitconfig`.
  - The external Catppuccin URL is used only by the existing `scripts/zsh.zsh` refresh command. No download is part of this inventory.
- Other modules:
  - `MIG-MODULE-mise` must provide the mise control plane before this dotfile declaration is applied.
  - `.config/mise/conf.d/tools.toml` installs `delta = "latest"`. `.config/mise/mise.lock` records delta `0.19.2` for the current locked tool.
  - The registry makes `MIG-MODULE-zsh` depend on `MIG-MODULE-delta` because the Zsh refresh script uses the delta target.
- User-facing behavior:
  - Git continues to use delta as its pager and diff filter, and the Catppuccin include remains available at the same target path.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch .config/delta/themes/catppuccin.gitconfig`
  - `zsh -n scripts/zsh.zsh`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/delta.md`
  - After the source move: `git ls-files --error-unmatch ~/dev/personal/dot/home/.config/delta/themes/catppuccin.gitconfig`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_delta.zsh` (planned module test; it is
    not present in the current tree.)
- Target smoke test:
  - `delta --version`
  - `test -f "$HOME/.config/delta/themes/catppuccin.gitconfig" && git config --global --get core.pager | grep -Fx delta && git config --global --get interactive.diffFilter | grep -Fx 'delta --color-only' && git config --global --get include.path | grep -Fx '~/.config/delta/themes/catppuccin.gitconfig'`
- Security or token check:
  - `! git grep -l -I -E '(token|password|secret|credential|private[ -]?key)' -- .config/delta ~/dev/personal/dot/home/.config/delta`
  - `git ls-files --others --ignored --exclude-standard -- .config/delta ~/dev/personal/dot/home/.config/delta`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/delta/themes/catppuccin.gitconfig`
  - The current target symlink text from `readlink "$HOME/.config/delta"`
  - The source and target checksums from `shasum .config/delta/themes/catppuccin.gitconfig "$HOME/.config/delta/themes/catppuccin.gitconfig"`
- Rollback dry run:
  - `mise -E delta dot unapply --dry-run ~/.config/delta`
  - `stow -nvR .`
- Rollback apply:
  - `mise -E delta dot unapply ~/.config/delta` after restoring the old source and declaration, then run `stow -vR .`
- Stop condition:
  - Stop if any dry run names an unexpected target, if a target-only file appears, if checksums change without an approved theme update, or if either Stow or mise still claims the target after rollback.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `delta` with dependency `MIG-MODULE-mise`.
  - `.config/git/config`, `.config/mise/conf.d/tools.toml`, `.config/mise/mise.lock`, `scripts/zsh.zsh`, and the target `readlink` result establish the Git, tool, script, and ownership coupling.
- Residual risk:
  - `scripts/zsh.zsh` writes the downloaded Catppuccin theme directly to the target path. With mise per-file links, that path would write through to the tracked `~/dev/personal/dot/home/` source. Migration validation must not run the refresh, and any future theme update needs explicit review.
- Open blocker:
  - Migration approval remains pending. Do not download or modify the theme.
