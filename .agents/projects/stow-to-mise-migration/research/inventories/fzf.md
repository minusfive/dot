# Module Inventory: `fzf`

## Metadata

- Module key: `fzf`
- Story key: `MIG-MODULE-fzf`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/fzf.md`
- Current declaration: `.config/fzf`
- New declaration: `home/.config/mise/conf.d/module.fzf.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/fzf`
- Mise mode: `symlink-each`
- Environment selector: `fzf`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path            | Tracked | Ignored | Current owner | Current target           | Target disposition | New source path             | New target               | New mode       | Notes                                                                                                                  |
| ---------------------- | ------- | ------- | ------------- | ------------------------ | ------------------ | --------------------------- | ------------------------ | -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `.config/fzf/fzf.conf` | `yes`   | `no`    | `stow`        | `~/.config/fzf/fzf.conf` | `migrate`          | `home/.config/fzf/fzf.conf` | `~/.config/fzf/fzf.conf` | `symlink-each` | Sole tracked file in the `.config/fzf` boundary; the current target is reached through a whole-directory Stow symlink. |

## Local and runtime inventory

| Path                   | Exists | Tracked | Ignored | Current location | Active use evidence                                                                         | Classification  | Required action   | Runtime destination      | Metadata to preserve                  | Secret or sensitive data |
| ---------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------- | --------------- | ----------------- | ------------------------ | ------------------------------------- | ------------------------ |
| `.config/fzf/fzf.conf` | `yes`  | `yes`   | `no`    | `repo`           | `.config/zsh/.zshrc:235` exports `FZF_DEFAULT_OPTS_FILE` to `$XDG_CONFIG_HOME/fzf/fzf.conf` | `active-global` | `copy-then-erase` | `~/.config/fzf/fzf.conf` | `mode 0644; preserve owner and group` | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

Both checks report no ignored paths. `git ls-files --others --exclude-standard
-- .config/fzf` also reports no non-ignored untracked paths.

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/fzf` (`readlink` is `../dev/personal/dot/.config/fzf`; the only resolved file is `~/.config/fzf/fzf.conf`)
- Old owner cleanup command: `test -L "$HOME/.config/fzf" && test "$(readlink "$HOME/.config/fzf")" = "../dev/personal/dot/.config/fzf" && rm "$HOME/.config/fzf"`
- New owner dry-run command: `mise -E fzf dot apply --dry-run ~/.config/fzf`
- New owner apply command: `mise -E fzf dot apply ~/.config/fzf`
- Duplicate-owner check: `test ! -e .config/fzf && ! stow -nvR . 2>&1 | grep -F '.config/fzf' && mise -E fzf dot status ~/.config/fzf`
- Target-content disposition check: `test -d "$HOME/.config/fzf" && test ! -L "$HOME/.config/fzf" && test -L "$HOME/.config/fzf/fzf.conf"`
- Relative-link check: `readlink "$HOME/.config/fzf/fzf.conf" | grep -qv '^/'`

## Coupling

- Scripts:
  - `.config/zsh/.zshrc:235` reads the deployed target through `FZF_DEFAULT_OPTS_FILE`; no script change is required because the target path remains unchanged.
- Environment variables:
  - `FZF_DEFAULT_OPTS_FILE` is set once in `.config/zsh/.zshrc:235` to `$XDG_CONFIG_HOME/fzf/fzf.conf`.
- Includes or external paths:
  - `none`
- Other modules:
  - `none`
- User-facing behavior:
  - Preserve the fzf defaults loaded from `~/.config/fzf/fzf.conf`; `symlink-each` keeps live target edits visible in the tracked `home/` source.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch .config/fzf/fzf.conf`
  - `cmp -s .config/fzf/fzf.conf home/.config/fzf/fzf.conf`
  - `grep -nF 'FZF_DEFAULT_OPTS_FILE' .config/zsh/.zshrc`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_fzf.zsh` (planned module test; include
    the staged-source probe and declaration ownership assertions)
- Target smoke test:
  - `printf 'probe\n' | FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/fzf.conf" fzf --filter=probe | grep -qx 'probe'`
- Security or token check:
  - `git ls-files --others --ignored --exclude-standard -- .config/fzf`
  - `! git grep -nEi '(token|password|secret|credential|private[_ -]?key)' -- .config/fzf >/dev/null`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/fzf/fzf.conf`, the `~/.config/fzf` symlink target and link text, and the source manifest from `git ls-files -- .config/fzf`.
- Rollback dry run:
  - `mise -E fzf dot unapply --dry-run ~/.config/fzf`
- Rollback apply:
  - `mise -E fzf dot unapply ~/.config/fzf && test -f .config/fzf/fzf.conf && test ! -e "$HOME/.config/fzf" && ln -s ../dev/personal/dot/.config/fzf "$HOME/.config/fzf"`
- Stop condition:
  - Stop if an unapply names any target other than `~/.config/fzf`, if the target contains unmanaged content, if the old source differs from the preserved manifest, or if the fzf smoke test fails.

## Findings and decisions

- Decision: `blocked`
- Decision evidence:
  - `.config/fzf/fzf.conf` is the sole tracked source, and the current target is the expected relative Stow directory symlink.
  - `.config/zsh/.zshrc:235` is the only active `FZF_DEFAULT_OPTS_FILE` reference.
- Residual risk:
  - The whole-directory Stow symlink must be detached before mise creates a physical target directory with a per-file link. No local extra files were observed.
- Open blocker:
  - Migration approval is pending.
