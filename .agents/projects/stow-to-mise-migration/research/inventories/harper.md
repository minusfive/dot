# Module Inventory: `harper`

## Metadata

- Module key: `harper`
- Story key: `MIG-MODULE-harper`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/harper.md`
- Current declaration: `.stowrc` implicit package-root ownership; no Harper-specific declaration
- New declaration: `home/.config/mise/conf.d/module.harper.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/harper`
- Mise mode: `symlink-each`
- Environment selector: `harper`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                            | Tracked | Ignored | Current owner | Current target                           | Target disposition | New source path                             | New target                               | New mode       | Notes                                                                        |
| -------------------------------------- | ------- | ------- | ------------- | ---------------------------------------- | ------------------ | ------------------------------------------- | ---------------------------------------- | -------------- | ---------------------------------------------------------------------------- |
| `.config/harper/dictionaries/user.txt` | `yes`   | `no`    | `Stow`        | `~/.config/harper/dictionaries/user.txt` | `migrate`          | `home/.config/harper/dictionaries/user.txt` | `~/.config/harper/dictionaries/user.txt` | `symlink-each` | Personal user dictionary. Do not copy its contents into migration artifacts. |

## Local and runtime inventory

| Path                                   | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                                      | Classification  | Required action   | Runtime destination                      | Metadata to preserve                                         | Secret or sensitive data                          |
| -------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------- | ----------------- | ---------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------- |
| `.config/harper/dictionaries/user.txt` | `yes`  | `yes`   | `no`    | `repo`           | `.config/nvim/lua/plugins/lang/grammar.lua` sets `userDictPath` to `~/.config/harper/dictionaries/user.txt`; the deployed path resolves through the Stow directory link. | `active-global` | `copy-then-erase` | `~/.config/harper/dictionaries/user.txt` | `0644`, `villalj:staff`, regular ASCII file                  | `yes; personal user data, not a credential store` |
| `~/.config/harper`                     | `yes`  | `no`    | `no`    | `target`         | Whole-directory relative symlink to `../dev/personal/dot/.config/harper`; it currently exposes the tracked dictionary.                                                   | `active-global` | `preserve`        | `~/.config/harper`                       | Whole-directory `lrwxr-xr-x`, `villalj:staff`, relative link | `yes through the linked dictionary`               |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/harper
# no output

git check-ignore -v .config/harper/dictionaries/user.txt
# no output; the dictionary is not Git-ignored
```

The boundary has no `.config/harper` rule in `.stow-local-ignore`. The
root-level `.harper-dictionary.txt` rule is unrelated to this source boundary.
The dictionary is tracked and contains personal user data; do not print its
contents during validation.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/harper` -> `../dev/personal/dot/.config/harper`; `~/.config/harper/dictionaries/user.txt` resolves to `.config/harper/dictionaries/user.txt`
- Old owner cleanup command: `test -L "$HOME/.config/harper" && test "$(readlink "$HOME/.config/harper")" = "../dev/personal/dot/.config/harper" && unlink "$HOME/.config/harper"`
- New owner dry-run command: `mise -E harper bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E harper bootstrap dotfiles apply --yes`
- Duplicate-owner check: `! stow -nvR . 2>&1 | grep -F -- '.config/harper' && mise -E harper bootstrap dotfiles status | grep -F -- '.config/harper/dictionaries/user.txt'`
- Target-content disposition check: `find -P "$HOME/.config/harper" -mindepth 1 -maxdepth 1 ! -name dictionaries -print -quit`
- Relative-link check: `python3 -c 'from pathlib import Path; p = Path.home() / ".config/harper/dictionaries/user.txt"; assert p.is_symlink() and not p.readlink().is_absolute() and p.resolve() == Path.cwd() / "home/.config/harper/dictionaries/user.txt"'`

## Coupling

- Scripts:
  - `scripts/mise.zsh` already applies the generic mise dotfiles phase; no Harper-specific phase or script change is required.
- Environment variables:
  - `none`; the Neovim Harper LSP configuration uses the fixed target path.
- Includes or external paths:
  - `.config/nvim/lua/plugins/lang/grammar.lua` references the target dictionary path.
- Other modules:
  - `MIG-MODULE-mise` provides the mise control-plane dependency recorded in `module-registry.toml`.
- User-facing behavior:
  - Preserve the Harper language-server user dictionary and its entries; change only ownership from the whole-directory Stow link to mise per-file linking.

## Validation

- Syntax or source checks:
  - `test -f .config/harper/dictionaries/user.txt && git ls-files --error-unmatch .config/harper/dictionaries/user.txt >/dev/null`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_harper.zsh` (planned module test; not present in the current baseline)
- Target smoke test:
  - `nvim --headless '+qa' && test -r "$HOME/.config/harper/dictionaries/user.txt" && test -L "$HOME/.config/harper/dictionaries/user.txt"`
- Security or token check:
  - `! grep -Eiq 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' .config/harper/dictionaries/user.txt home/.config/harper/dictionaries/user.txt 2>/dev/null`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/harper/dictionaries/user.txt` with mode `0644` and the current `~/.config/harper` whole-directory symlink manifest.
- Rollback dry run:
  - `mise -E harper bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise -E harper bootstrap dotfiles unapply --yes && test ! -e "$HOME/.config/harper" -o -L "$HOME/.config/harper" && stow -vR .`
- Stop condition:
  - Stop if the target contains any child other than `dictionaries`, if the existing whole-directory link does not match the recorded target, if mise or Stow reports a conflict, or if any unexpected sensitive/runtime file appears in the source set.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `harper` and its dependency on `MIG-MODULE-mise`.
  - `.config/nvim/lua/plugins/lang/grammar.lua` references the deployed user dictionary path.
  - The source dictionary is tracked, not Git-ignored, and currently deployed through the recorded whole-directory Stow symlink. No Harper-specific Stow ignore rule exists.
- Residual risk:
  - `medium`; the boundary contains personal user data that must remain private and visible through a symlink, and cutover must remove only the recorded whole-directory link before mise creates per-file links.
- Open blocker:
  - Explicit migration approval is required before changing ownership. No
    Harper-specific focused test exists in the current baseline.
