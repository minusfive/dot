# Module Inventory: `tmux`

## Metadata

- Module key: `tmux`
- Story key: `MIG-MODULE-tmux`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/tmux.md`
- Current declaration: `.stowrc` implicit package-root ownership; no tmux-specific declaration
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.tmux.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/tmux`
- Mise mode: `symlink-each`
- Environment selector: `tmux`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path              | Tracked | Ignored | Current owner | Current target             | Target disposition | New source path                                  | New target                 | New mode       | Notes                                                                             |
| ------------------------ | ------- | ------- | ------------- | -------------------------- | ------------------ | ------------------------------------------------ | -------------------------- | -------------- | --------------------------------------------------------------------------------- |
| `.config/tmux/tmux.conf` | `yes`   | `no`    | `Stow`        | `~/.config/tmux/tmux.conf` | `migrate`          | `~/dev/personal/dot/home/.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | `symlink-each` | The only source file. It declares TPM plugins and runs `~/.tmux/plugins/tpm/tpm`. |

## Local and runtime inventory

| Path                      | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                       | Classification                | Required action   | Runtime destination        | Metadata to preserve                                         | Secret or sensitive data |
| ------------------------- | ------ | ------- | ------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ----------------- | -------------------------- | ------------------------------------------------------------ | ------------------------ |
| `.config/tmux/tmux.conf`  | `yes`  | `yes`   | `no`    | `repo`           | The deployed `~/.config/tmux/tmux.conf` resolves through the current whole-directory Stow link. The isolated tmux parse smoke test exits with status `0`. | `active-global`               | `copy-then-erase` | `~/.config/tmux/tmux.conf` | `0644`, `villalj:staff`                                      | `no`                     |
| `~/.config/tmux`          | `yes`  | `no`    | `no`    | `target`         | Whole-directory relative symlink to `../dev/personal/dot/.config/tmux`; it exposes the tracked `tmux.conf` file.                                          | `active-global`               | `preserve`        | `~/.config/tmux`           | Whole-directory `lrwxr-xr-x`, `villalj:staff`, relative link | `no`                     |
| `~/.tmux/plugins/tpm/tpm` | `no`   | `no`    | `no`    | `target`         | `tmux.conf` references this path with `run`; TPM is not installed on the current machine.                                                                 | `external-runtime-dependency` | `none`            | `~/.tmux/plugins/tpm/tpm`  | Not present                                                  | `no`                     |

Record ignored paths with:

```text
git ls-files --others --exclude-standard -- .config/tmux
# no output

git ls-files --others --ignored --exclude-standard -- .config/tmux
# no output

git check-ignore -v .config/tmux/tmux.conf
# no output; the source file is not Git-ignored
```

The `.config/tmux` boundary has no matching `.stow-local-ignore` or Git ignore
rule. The future `~/dev/personal/dot/home/.config/tmux` source is excluded from Stow by the
existing `^/home` rule. The `.config/zsh/.zcompdump` file has an `_tmux`
completion reference, but it is generated runtime state outside this boundary
and is ignored by the global Git ignore file.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/tmux` -> `../dev/personal/dot/.config/tmux`; `~/.config/tmux/tmux.conf` resolves to `.config/tmux/tmux.conf`
- Old owner cleanup command: `test -L "$HOME/.config/tmux" && test "$(readlink "$HOME/.config/tmux")" = "../dev/personal/dot/.config/tmux" && unlink "$HOME/.config/tmux"`
- New owner dry-run command: `mise -E tmux bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E tmux bootstrap dotfiles apply --yes`
- Duplicate-owner check: `! stow -nvR . 2>&1 | grep -F -- '.config/tmux' && mise -E tmux bootstrap dotfiles status | grep -F -- '.config/tmux/tmux.conf'`
- Target-content disposition check: `find -P "$HOME/.config/tmux" -mindepth 1 -maxdepth 1 ! -name tmux.conf -print -quit`
- Relative-link check: `python3 -c 'from pathlib import Path; p = Path.home() / ".config/tmux/tmux.conf"; assert p.is_symlink() and not p.readlink().is_absolute() and p.resolve() == Path.home() / "dev/personal/dot/home/.config/tmux/tmux.conf"'`

## Coupling

- Scripts:
  - `scripts/symlink.zsh` applies the current Stow owner with `stow -vR .`; no tmux-specific change is required until cutover.
  - `scripts/mise.zsh` applies the existing mise dotfiles phase; no new initialization phase is required for the tmux module.
- Environment variables:
  - `MISE_ENV=tmux` selects the module for focused mise validation.
  - `DOT_PROFILE` selects the top-level mise profile; it does not change the tmux source path.
  - No tmux-specific environment variable reference exists in the repository.
- Includes or external paths:
  - `~/.tmux/plugins/tpm/tpm` is the external path from the `run` directive. The path is absent on the current machine.
  - `tmux.conf` declares `tmux-plugins/tpm`, `tmux-plugins/tmux-sensible`, `catppuccin/tmux`, `sainnhe/tmux-fzf`, `b0o/tmux-autoreload`, and `alexwforsythe/tmux-which-key`; the plugin manager owns their runtime files.
- Other modules:
  - `MIG-MODULE-mise` provides the control-plane dependency recorded in `module-registry.toml`.
  - The `packages` module installs the `tmux` executable through `"brew:tmux" = "latest"` in `.config/mise/conf.d/bootstrap-packages.toml`.
  - `.config/nvim/lua/plugins/snacks.lua` uses a tmux escape sequence and documents the optional `allow-passthrough` setting. The current setting remains commented in `tmux.conf`.
  - `.config/bat/config` and the Hammerspoon annotation contain tmux text for compatibility, documentation, or comments. They do not reference the tmux source path.
  - `.harper-dictionary.txt` contains `tmux` as a dictionary word. Ignored WezTerm research output contains archived search text. Neither file is runtime coupling.
- User-facing behavior:
  - Preserve the top status bar, `C-Space` prefix, plugin declarations, TPM initialization, and terminal color overrides.

## Validation

- Syntax or source checks:
  - `test -f .config/tmux/tmux.conf && grep -Fq 'set -g prefix C-Space' .config/tmux/tmux.conf && grep -Fq "run '~/.tmux/plugins/tpm/tpm'" .config/tmux/tmux.conf`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_tmux.zsh` (planned module test; not present in the current baseline)
- Target smoke test:
  - `socket="dot-tmux-parse-$$"; tmux -L "$socket" -f "$HOME/.config/tmux/tmux.conf" -C start-server >/dev/null 2>&1; status=$?; tmux -L "$socket" kill-server >/dev/null 2>&1 || true; exit "$status"`
  - Defer plugin-load validation until TPM is installed.
- Security or token check:
  - `! grep -Eiq 'token|password|secret|credential|private[[:space:]-]?key|auth[.]db' .config/tmux/tmux.conf ~/dev/personal/dot/home/.config/tmux/tmux.conf`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/tmux/tmux.conf` with mode `0644` and the current `~/.config/tmux` symlink manifest.
- Rollback dry run:
  - `mise -E tmux bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise -E tmux bootstrap dotfiles unapply --yes && test ! -e "$HOME/.config/tmux/tmux.conf" && { test ! -e "$HOME/.config/tmux" || rmdir "$HOME/.config/tmux"; } && stow -vR .`
- Stop condition:
  - Stop if the target contains any child other than `tmux.conf`, if the existing whole-directory link does not match the recorded target, if mise or Stow reports a conflict, if the parse smoke test fails, or if any sensitive or unmanaged file appears.

## Findings and decisions

- Decision: `resolved`
- Resolved decision: `DEC-tmux-runtime-classification`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `tmux` and its dependency on `MIG-MODULE-mise`.
  - The current target is the recorded whole-directory relative Stow symlink, and the isolated tmux parse smoke test exits with status `0`.
  - TPM is an external, unmanaged runtime dependency. It remains outside the
    migration source set.
- Residual risk:
  - `low`; the boundary has one tracked, non-sensitive file and no unmanaged child, but the referenced TPM runtime path is absent and the parse test does not prove that plugins load.
- Open blocker:
  - Explicit migration approval is required before changing ownership.
