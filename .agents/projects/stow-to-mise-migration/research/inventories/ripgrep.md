# Module Inventory: `ripgrep`

## Metadata

- Module key: `ripgrep`
- Story key: `MIG-MODULE-ripgrep`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/ripgrep.md`
- Current declaration: `.stowrc`
- New declaration: `home/.config/mise/conf.d/module.ripgrep.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/ripgrep`
- Mise mode: `symlink-each`
- Environment selector: `ripgrep`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                  | Tracked | Ignored | Current owner | Current target                                                       | Target disposition | New source path                   | New target                     | New mode       | Notes                                                                                        |
| ---------------------------- | ------- | ------- | ------------- | -------------------------------------------------------------------- | ------------------ | --------------------------------- | ------------------------------ | -------------- | -------------------------------------------------------------------------------------------- |
| `.config/ripgrep/.ripgreprc` | `yes`   | `no`    | `stow`        | `~/.config/ripgrep/.ripgreprc` through the current directory symlink | `migrate`          | `home/.config/ripgrep/.ripgreprc` | `~/.config/ripgrep/.ripgreprc` | `symlink-each` | Preserve the existing ripgrep options and keep the live target linked to the tracked source. |

## Local and runtime inventory

| Path                           | Exists | Tracked | Ignored | Current location                   | Active use evidence                                                        | Classification  | Required action | Runtime destination                                                     | Metadata to preserve                                                                                                   | Secret or sensitive data |
| ------------------------------ | ------ | ------- | ------- | ---------------------------------- | -------------------------------------------------------------------------- | --------------- | --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/ripgrep/.ripgreprc`   | `yes`  | `yes`   | `no`    | `repo`                             | `.config/zsh/.zshrc:225` exports `RIPGREP_CONFIG_PATH` to the target file. | `active-global` | `move`          | `~/.config/ripgrep/.ripgreprc`                                          | Regular file, `0644`, owner `villalj`, group `staff`                                                                   | `no`                     |
| `~/.config/ripgrep`            | `yes`  | `no`    | `no`    | `target`                           | The target is resolved by `RIPGREP_CONFIG_PATH` through `.ripgreprc`.      | `active-global` | `remove`        | `~/.config/ripgrep` as a physical directory managed with `symlink-each` | Relative directory symlink, `lrwxr-xr-x`, owner `villalj`, group `staff`, target `../dev/personal/dot/.config/ripgrep` | `no`                     |
| `~/.config/ripgrep/.ripgreprc` | `yes`  | `no`    | `no`    | `target through directory symlink` | Resolves to `.config/ripgrep/.ripgreprc`; no separate target copy exists.  | `active-global` | `preserve`      | `~/.config/ripgrep/.ripgreprc` as a mise-managed relative symlink       | Regular file reached through the directory symlink, `0644`, owner `villalj`, group `staff`                             | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/ripgrep
git check-ignore -v <path>
```

Both checks produce no output for this boundary. `.stow-local-ignore` has no
ripgrep-specific rule, and no ignored or untracked files exist below
`.config/ripgrep`. The source `.ripgreprc` itself configures ripgrep to include
hidden files, exclude `.git/*`, and use smart case; these are tool rules, not
repository ownership exclusions.

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/ripgrep` -> `../dev/personal/dot/.config/ripgrep`; `.ripgreprc` is reached through this directory link and is not a separate target symlink.
- Old owner cleanup command: `test "$(readlink "$HOME/.config/ripgrep")" = "../dev/personal/dot/.config/ripgrep" && rm "$HOME/.config/ripgrep"`
- New owner dry-run command: `mise -C "$HOME/dev/personal/dot" dot apply --dry-run ~/.config/ripgrep`
- New owner apply command: `mise -C "$HOME/dev/personal/dot" dot apply ~/.config/ripgrep`
- Duplicate-owner check: `! stow -nvR . 2>&1 | grep -F '.config/ripgrep' && mise bootstrap dotfiles status | grep -F '.config/ripgrep'`
- Target-content disposition check: `find "$HOME/.config/ripgrep" -maxdepth 1 -type f -print`
- Relative-link check: `readlink "$HOME/.config/ripgrep/.ripgreprc" | grep -qv '^/'`

## Coupling

- Scripts:
  - None.
- Environment variables:
  - `RIPGREP_CONFIG_PATH` is exported by `.config/zsh/.zshrc:225` as `$XDG_CONFIG_HOME/ripgrep/.ripgreprc`; preserve this target-relative path.
- Includes or external paths:
  - None.
- Other modules:
  - `mise`; the module depends on the mise control-plane boundary.
- User-facing behavior:
  - Preserve line numbers, hidden-file search, `.git/*` exclusion, and automatic case sensitivity from `.ripgreprc`.

## Validation

- Syntax or source checks:
  - `test -f .config/ripgrep/.ripgreprc && git ls-files --error-unmatch .config/ripgrep/.ripgreprc`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_ripgrep.zsh` (planned module test;
    include the configured-source probe)
- Target smoke test:
  - `test -f "$HOME/.config/ripgrep/.ripgreprc" && RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/.ripgreprc" rg --files "$HOME/dev/personal/dot" | grep -Fx "$HOME/dev/personal/dot/.config/ripgrep/.ripgreprc"`
- Security or token check:
  - `git grep -nE '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]+|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY)' -- .config/ripgrep || true`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/ripgrep/.ripgreprc` and the pre-cutover target manifest from `readlink "$HOME/.config/ripgrep"`.
- Rollback dry run:
  - `mise -C "$HOME/dev/personal/dot" dot unapply --dry-run ~/.config/ripgrep`
- Rollback apply:
  - `mise -C "$HOME/dev/personal/dot" dot unapply ~/.config/ripgrep && stow -R .`
- Stop condition:
  - Stop if either dry run names a target outside `~/.config/ripgrep`, finds a physical target file or unexpected local entry, or proposes another owner for the boundary.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md:394-401`
  - `stow -nvR .` reports the current whole-directory symlink at `.config/ripgrep`.
- Residual risk:
  - The cutover must detach the existing whole-directory symlink before applying per-file mise links; an unexpected local target entry must not be removed.
- Open blocker:
  - Migration approval and creation of `home/.config/ripgrep/.ripgreprc` plus `home/.config/mise/conf.d/module.ripgrep.toml` remain pending.
