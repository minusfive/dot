# Module Inventory: `wezterm`

## Metadata

- Module key: `wezterm`
- Story key: `MIG-MODULE-wezterm`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/wezterm.md`
- Current declaration: `.stowrc` implicit package-root ownership; no wezterm-specific declaration
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.wezterm.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/wezterm`
- Mise mode: `symlink-each`
- Environment selector: `wezterm`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                  | Tracked | Ignored | Current owner   | Current target                            | Target disposition | New source path                                                 | New target                                | New mode       | Notes                                                                                                                                                                                                                 |
| -------------------------------------------- | ------- | ------- | --------------- | ----------------------------------------- | ------------------ | --------------------------------------------------------------- | ----------------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/wezterm/wezterm.lua`                | `yes`   | `no`    | `Stow`          | `~/.config/wezterm/wezterm.lua`           | `migrate`          | `~/dev/personal/dot/home/.config/wezterm/wezterm.lua`           | `~/.config/wezterm/wezterm.lua`           | `symlink-each` | Stable WezTerm configuration. It uses a remote Catppuccin plugin and the machine path `wezterm.home_dir .. "/dev"`.                                                                                                   |
| `.config/wezterm/shell-completion.zsh`       | `yes`   | `no`    | `Stow`          | `~/.config/wezterm/shell-completion.zsh`  | `migrate`          | `~/dev/personal/dot/home/.config/wezterm/shell-completion.zsh`  | `~/.config/wezterm/shell-completion.zsh`  | `symlink-each` | Tracked Zsh completion hook; preserve the `wezterm shell-completion --shell zsh` behavior.                                                                                                                            |
| `.config/wezterm/shell-integration.zsh`      | `yes`   | `no`    | `Stow`          | `~/.config/wezterm/shell-integration.zsh` | `migrate`          | `~/dev/personal/dot/home/.config/wezterm/shell-integration.zsh` | `~/.config/wezterm/shell-integration.zsh` | `symlink-each` | Tracked Zsh integration hook; preserve the `WEZTERM_EXECUTABLE_DIR` resource lookup.                                                                                                                                  |
| `.config/wezterm/AGENTS.md`                  | `yes`   | `no`    | `Stow-excluded` | `~/.config/wezterm/AGENTS.md`             | `repository-only`  | `none`                                                          | `none`                                    | `none`         | Repository-local instructions. `.stow-local-ignore` excludes this path; keep it in `.config/wezterm`, not `~/dev/personal/dot/home/`.                                                                                 |
| `.config/wezterm/CLAUDE.md`                  | `yes`   | `no`    | `Stow-excluded` | `~/.config/wezterm/CLAUDE.md`             | `repository-only`  | `none`                                                          | `none`                                    | `none`         | Repository-local instruction symlink to `AGENTS.md`. `.stow-local-ignore` excludes this path; keep it in `.config/wezterm`, not `~/dev/personal/dot/home/`.                                                           |
| `~/.config/wezterm` (current parent symlink) | `no`    | `no`    | `Stow`          | `~/.config/wezterm`                       | `remove`           | `none`                                                          | `none`                                    | `none`         | Whole-directory relative symlink to `../dev/personal/dot/.config/wezterm`; it currently exposes managed files, repository-only files, research, and temporary backups. Remove only after the recorded dry run passes. |

## Local and runtime inventory

| Path                                    | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                         | Classification     | Required action | Runtime destination                       | Metadata to preserve                                        | Secret or sensitive data |
| --------------------------------------- | ------ | ------- | ------- | ---------------- | ----------------------------------------------------------------------------------------------------------- | ------------------ | --------------- | ----------------------------------------- | ----------------------------------------------------------- | ------------------------ |
| `.config/wezterm/wezterm.lua`           | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; configuration moved to `home/.config/wezterm/wezterm.lua`.                             | `historical`       | `remove`        | `~/.config/wezterm/wezterm.lua`           | `retired source path`                                       | `no`                     |
| `.config/wezterm/shell-completion.zsh`  | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; hook moved to `home/.config/wezterm/shell-completion.zsh`.                             | `historical`       | `remove`        | `~/.config/wezterm/shell-completion.zsh`  | `retired source path`                                       | `no`                     |
| `.config/wezterm/shell-integration.zsh` | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; hook moved to `home/.config/wezterm/shell-integration.zsh`.                            | `historical`       | `remove`        | `~/.config/wezterm/shell-integration.zsh` | `retired source path`                                       | `no`                     |
| `.config/wezterm/AGENTS.md`             | `yes`  | `yes`   | `no`    | `repo`           | Repository instructions apply when files under `.config/wezterm/` change; Stow excludes the path.           | `active-repo-only` | `none`          | `none`                                    | `0644`, `villalj:staff`                                     | `no`                     |
| `.config/wezterm/CLAUDE.md`             | `yes`  | `yes`   | `no`    | `repo`           | Repository instruction symlink resolves to `AGENTS.md`; Stow excludes the path.                             | `active-repo-only` | `none`          | `none`                                    | `lrwxr-xr-x`, relative link to `AGENTS.md`, `villalj:staff` | `no`                     |
| `~/.config/wezterm`                     | `yes`  | `no`    | `no`    | `target`         | Physical directory with three managed links; repository-only instructions remain only in `.config/wezterm`. | `active-global`    | `preserve`      | `~/.config/wezterm`                       | `Physical directory, owner villalj:staff, mode 0755`        | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/wezterm
```

The `AGENTS.md`/`CLAUDE.md` files are excluded by `.stow-local-ignore`.
The current parent symlink exposes those repository-only paths until the
Stow link is detached.

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links`
- Current target manifest path: `~/.config/wezterm`
- Old owner cleanup command: `test -L "$HOME/.config/wezterm" && test "$(readlink "$HOME/.config/wezterm")" = "../dev/personal/dot/.config/wezterm" && unlink "$HOME/.config/wezterm"`
- New owner dry-run command: `mise -E wezterm bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E wezterm bootstrap dotfiles apply --yes`
- Duplicate-owner check: `! stow -nvR . 2>&1 | grep -F -- '.config/wezterm' && mise -E wezterm bootstrap dotfiles status | grep -F -- '.config/wezterm/'`
- Target-content disposition check: `find -P "$HOME/.config/wezterm" -mindepth 1 -maxdepth 1 ! -name wezterm.lua ! -name shell-completion.zsh ! -name shell-integration.zsh -print -quit`
- Relative-link check: `python3 -c 'from pathlib import Path; root = Path.home() / ".config/wezterm"; expected = Path.home() / "dev/personal/dot/home/.config/wezterm"; names = ("wezterm.lua", "shell-completion.zsh", "shell-integration.zsh"); assert all((root / name).is_symlink() and not (root / name).readlink().is_absolute() and (root / name).resolve() == expected / name for name in names)'`

## Coupling

- Scripts:
  - `scripts/mise.zsh` applies the existing mise dotfiles phase after package, workspace, tool, and repository bootstrap; no WezTerm-specific phase or script change is required.
  - `scripts/init.zsh --mise` reaches the same existing dotfiles phase; no initialization ordering change is required.
- Environment variables:
  - `DOT_PROFILE` selects the rendered module list in `.config/mise/miserc.toml`; the planned `wezterm` module must remain in both profile lists.
  - `MISE_ENV` is set to the selected profile by `scripts/mise.zsh`; use `mise -E wezterm` for module-focused validation.
  - `WEZTERM_EXECUTABLE_DIR` is consumed by `shell-integration.zsh` to locate the installed WezTerm resource script.
- Includes or external paths:
  - `wezterm.lua` loads `https://github.com/minusfive/catppuccin-wezterm` through WezTerm's plugin loader.
  - `wezterm.lua` derives `TERMINFO_DIRS` from the installed WezTerm `Resources` directory and sets the default working directory from `wezterm.home_dir .. "/dev"`.
  - `shell-integration.zsh` sources the installed `Resources/wezterm.sh` path derived from `WEZTERM_EXECUTABLE_DIR`.
- Other modules:
  - `MIG-MODULE-mise` provides the control-plane dependency recorded in `module-registry.toml`.
  - The `packages` module installs `brew-cask:wezterm@nightly`; this is package/runtime coupling, not a source-path reference.
- User-facing behavior:
  - Preserve WezTerm configuration, pane behavior, shell completion, and shell integration. Change only ownership from the whole-directory Stow link to mise per-file links; keep repository instructions unmanaged.

## Validation

- Syntax or source checks:
  - `test -f home/.config/wezterm/wezterm.lua && test -f home/.config/wezterm/shell-completion.zsh && test -f home/.config/wezterm/shell-integration.zsh && zsh -n home/.config/wezterm/shell-completion.zsh && zsh -n home/.config/wezterm/shell-integration.zsh`
  - `test "$(readlink .config/wezterm/CLAUDE.md)" = "AGENTS.md"`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_wezterm.zsh` (planned module test; not present in the current baseline)
- Target smoke test:
  - `zsh -n ~/dev/personal/dot/home/.config/wezterm/shell-completion.zsh && zsh -n ~/dev/personal/dot/home/.config/wezterm/shell-integration.zsh && wezterm --config-file ~/.config/wezterm/wezterm.lua show-keys`
- Security or token check:
  - `! grep -Eiq 'token|password|secret|credential|private[[:space:]-]?key|auth[.]db' home/.config/wezterm/wezterm.lua home/.config/wezterm/shell-completion.zsh home/.config/wezterm/shell-integration.zsh`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/wezterm/wezterm.lua`, `.config/wezterm/shell-completion.zsh`, `.config/wezterm/shell-integration.zsh`, and the exact `~/.config/wezterm` parent symlink manifest.
- Rollback dry run:
  - `mise -E wezterm bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise -E wezterm bootstrap dotfiles unapply --yes && test ! -e "$HOME/.config/wezterm" -o -L "$HOME/.config/wezterm" && stow -vR .`
- Stop condition:
  - Stop if the target is not the recorded whole-directory Stow link before cutover, if any unmanaged target content is found, if mise or Stow reports a conflict, if repository-only files or research state are copied into `~/dev/personal/dot/home/`, or if a sensitive/runtime file appears in the migrated source set.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `wezterm` and its dependency on `MIG-MODULE-mise`.
  - The current target is the exact relative parent symlink `../dev/personal/dot/.config/wezterm`; it exposes the managed files and Stow-excluded repository instructions.
  - `.stow-local-ignore` excludes `AGENTS.md` and `CLAUDE.md`.
  - The non-disclosing security scan found no token, password, secret, credential, private-key, or authentication-database marker in the tracked configuration and hooks. The WezTerm plugin URL and machine paths remain coupling risks.
- Residual risk:
  - `medium`; the migrated configuration loads a remote plugin and uses machine-specific paths.
- Open blocker:
  - None. Repository-only instruction files remain in `.config/wezterm` and
    are excluded from the mise source boundary.
