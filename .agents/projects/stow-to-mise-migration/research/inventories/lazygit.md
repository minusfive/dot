# Module Inventory: `lazygit`

## Metadata

- Module key: `lazygit`
- Story key: `MIG-MODULE-lazygit`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/lazygit.md`
- Current declaration: `.stowrc` (`--target=~`), applied by `scripts/symlink.zsh`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.lazygit.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/lazygit`
- Mise mode: `symlink-each`
- Environment selector: `lazygit`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                  | Tracked | Ignored | Current owner | Current target                 | Target disposition | New source path                                      | New target                     | New mode       | Notes                                                        |
| ---------------------------- | ------- | ------- | ------------- | ------------------------------ | ------------------ | ---------------------------------------------------- | ------------------------------ | -------------- | ------------------------------------------------------------ |
| `.config/lazygit/config.yml` | `yes`   | `no`    | `Stow`        | `~/.config/lazygit/config.yml` | `migrate`          | `~/dev/personal/dot/home/.config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | `symlink-each` | Stable repository-owned configuration; preserve mode `0644`. |
| `.config/lazygit/theme.yml`  | `yes`   | `no`    | `Stow`        | `~/.config/lazygit/theme.yml`  | `migrate`          | `~/dev/personal/dot/home/.config/lazygit/theme.yml`  | `~/.config/lazygit/theme.yml`  | `symlink-each` | Stable repository-owned theme; preserve mode `0644`.         |

## Local and runtime inventory

| Path                         | Exists | Tracked | Ignored | Current location | Active use evidence                                                | Classification  | Required action   | Runtime destination            | Metadata to preserve                                                                                                         | Secret or sensitive data |
| ---------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------ | --------------- | ----------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/lazygit/config.yml` | `yes`  | `yes`   | `no`    | `repo`           | `.config/zsh/.zshrc:222` names its target through `LG_CONFIG_FILE` | `active-global` | `copy-then-erase` | `~/.config/lazygit/config.yml` | Regular file, mode `0644`                                                                                                    | `no`                     |
| `.config/lazygit/theme.yml`  | `yes`  | `yes`   | `no`    | `repo`           | `.config/zsh/.zshrc:222` names its target through `LG_CONFIG_FILE` | `active-global` | `copy-then-erase` | `~/.config/lazygit/theme.yml`  | Regular file, mode `0644`                                                                                                    | `no`                     |
| `~/.config/lazygit`          | `yes`  | `no`    | `no`    | `target`         | `LG_CONFIG_FILE` resolves both child files under this directory    | `active-global` | `preserve`        | `~/.config/lazygit`            | Whole-directory relative symlink `../dev/personal/dot/.config/lazygit`; link mode `0755`; child files resolve to mode `0644` | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/lazygit
git check-ignore -v <path>
```

No ignored or non-ignored untracked files exist under `.config/lazygit`. The
source manifest contains only the two tracked files listed above. Do not print
credential-bearing contents. Record metadata, references, and target paths only.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/lazygit` (`readlink` returns `../dev/personal/dot/.config/lazygit`)
- Old owner cleanup command: `test -L "$HOME/.config/lazygit" && test "$(readlink "$HOME/.config/lazygit")" = "../dev/personal/dot/.config/lazygit" && unlink "$HOME/.config/lazygit"`
- New owner dry-run command: `mise -E lazygit dot apply --dry-run ~/.config/lazygit`
- New owner apply command: `mise -E lazygit dot apply --yes ~/.config/lazygit`
- Duplicate-owner check: `test ! -e .config/lazygit && ! stow -nvR . 2>&1 | grep -F '.config/lazygit' && mise -E lazygit dot status ~/.config/lazygit`
- Target-content disposition check: `test -d "$HOME/.config/lazygit" && test ! -L "$HOME/.config/lazygit" && test "$(realpath "$HOME/.config/lazygit/config.yml")" = "$(realpath "$HOME/dev/personal/dot/home/.config/lazygit/config.yml")" && test "$(realpath "$HOME/.config/lazygit/theme.yml")" = "$(realpath "$HOME/dev/personal/dot/home/.config/lazygit/theme.yml")"`
- Relative-link check: `case "$(readlink "$HOME/.config/lazygit/config.yml")" in /*) exit 1;; esac; case "$(readlink "$HOME/.config/lazygit/theme.yml")" in /*) exit 1;; esac`

## Coupling

- Scripts:
  - `.config/zsh/.zshrc:222` reads both deployed files through `LG_CONFIG_FILE`; no script change is required because the target paths remain unchanged.
- Environment variables:
  - `LG_CONFIG_FILE` is set by `.config/zsh/.zshrc:222` to `$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/theme.yml`.
- Includes or external paths:
  - Both YAML files contain a Lazygit schema URL comment. `config.yml` invokes the `delta` executable for diff rendering; it has no local file include.
- Other modules:
  - `MIG-MODULE-mise` provides the control plane. `bootstrap-packages.toml` installs the `lazygit` executable, and `tools.toml` provides `delta`. Neither package module owns `~/.config/lazygit`.
- User-facing behavior:
  - Lazygit must continue loading the same config and theme files through `LG_CONFIG_FILE`; only the repository source location and ownership change.

## Validation

- Syntax or source checks:
  - `git ls-files -- .config/lazygit | sort`
  - `yq eval '.' .config/lazygit/config.yml >/dev/null && yq eval '.' .config/lazygit/theme.yml >/dev/null`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_lazygit.zsh` (planned module
    test; not present in the current tree)
- Target smoke test:
  - `LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme.yml" lazygit --version`
- Security or token check:
  - `! git grep -nEi '(token|password|secret|credential|api[-_ ]?key|private[-_ ]?key)' -- .config/lazygit >/dev/null`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/lazygit/config.yml`, `.config/lazygit/theme.yml`, the current target link `~/.config/lazygit`, and the source and target manifests.
- Rollback dry run:
  - `mise -E lazygit dot unapply --dry-run ~/.config/lazygit`
- Rollback apply:
  - `mise -E lazygit dot unapply --yes ~/.config/lazygit && test ! -e "$HOME/.config/lazygit" && ln -s ../dev/personal/dot/.config/lazygit "$HOME/.config/lazygit" && stow -vR .`
- Stop condition:
  - Stop if the target is not the recorded Stow symlink before cutover, contains unmanaged files, either mise dry run names an unexpected target, or the `LG_CONFIG_FILE` smoke test fails.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `git ls-files -- .config/lazygit` reports exactly `config.yml` and `theme.yml`.
  - `stow -nvR .` reports the current `.config/lazygit` unlink/link pair.
  - `readlink "$HOME/.config/lazygit"` returns `../dev/personal/dot/.config/lazygit`.
  - `.config/zsh/.zshrc:222` is the only non-history `LG_CONFIG_FILE` reference.
  - Both YAML files parse with `yq`, and Lazygit starts with both configured files when invoked with `--version`.
- Residual risk:
  - The current parent-directory Stow link must be detached before per-file
    mise links are applied.
- Open blocker:
  - Migration approval remains pending, and the planned module-focused test
    does not yet exist.
