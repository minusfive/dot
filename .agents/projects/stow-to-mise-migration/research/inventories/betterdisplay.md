# Module Inventory: `betterdisplay`

## Metadata

- Module key: `betterdisplay`
- Story key: `MIG-MODULE-betterdisplay`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/betterdisplay.md`
- Current declaration: `.stowrc` implicit package-root ownership via `scripts/symlink.zsh`; BetterDisplay behavior is coupled through `scripts/betterdisplay.zsh`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.betterdisplay.toml`
- Current owner: `Stow + script`
- New owner: `mise + script`
- Target root: `~/.config/BetterDisplay`
- Mise mode: `symlink-each`
- Environment selector: `betterdisplay`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                          | Tracked | Ignored | Current owner   | Current target                                  | Target disposition | New source path                                              | New target                                      | New mode       | Notes                                                                                                                                                                                      |
| ------------------------------------ | ------- | ------- | --------------- | ----------------------------------------------- | ------------------ | ------------------------------------------------------------ | ----------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.config/BetterDisplay/config.plist` | `yes`   | `no`    | `Stow + script` | `~/.config/BetterDisplay/config.plist`          | `migrate`          | `~/dev/personal/dot/home/.config/BetterDisplay/config.plist` | `~/.config/BetterDisplay/config.plist`          | `symlink-each` | Apple binary plist; preserve its machine-specific display configuration and filtered identifier fields without printing plist contents.                                                    |
| `.config/BetterDisplay/README.md`    | `yes`   | `no`    | `Stow`          | `~/.config/BetterDisplay/README.md`             | `repository-only`  | `~/dev/personal/dot/home/.config/BetterDisplay/README.md`    | `none`                                          | `none`         | Preserve the README in the `~/dev/personal/dot/home/` source tree, remove its deployed target entry, and do not add it to the mise declaration.                                            |
| `none`                               | `no`    | `no`    | `script`        | `~/.config/BetterDisplay/config.backup.*.plist` | `preserve`         | `none`                                                       | `~/.config/BetterDisplay/config.backup.*.plist` | `none`         | No backup files are present in the current target scan. Preserve any future backups as target-only runtime files; never copy them into `~/dev/personal/dot/home/` or declare them in mise. |

## Local and runtime inventory

| Path                                            | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                                                                        | Classification     | Required action   | Runtime destination                             | Metadata to preserve                                                        | Secret or sensitive data                                                                                             |
| ----------------------------------------------- | ------ | ------- | ------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------- | ----------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `.config/BetterDisplay/config.plist`            | `yes`  | `yes`   | `no`    | `repo`           | `scripts/betterdisplay.zsh` exports and imports the `pro.betterdisplay.BetterDisplay` bundle settings; `plutil -lint` reports `OK`.                                                                        | `active-global`    | `copy-then-erase` | `~/.config/BetterDisplay/config.plist`          | `0644`, owner `villalj`, group `staff`, Apple binary plist                  | `yes` — machine-specific display UUID, serial, EDID, and color-profile references; no credential content was printed |
| `.config/BetterDisplay/README.md`               | `yes`  | `yes`   | `no`    | `repo`           | Documents the bootstrap and manual export/import flows, backup pattern, display-identifier limitations, and app-version compatibility.                                                                     | `active-repo-only` | `preserve`        | `none`                                          | `0644`, owner `villalj`, group `staff`                                      | `no`                                                                                                                 |
| `~/.config/BetterDisplay`                       | `yes`  | `no`    | `no`    | `target`         | BetterDisplay is installed at `/Applications/BetterDisplay.app`; the target is a relative whole-directory symlink to `../dev/personal/dot/.config/BetterDisplay`; the app is not running during inventory. | `active-global`    | `preserve`        | `~/.config/BetterDisplay`                       | Whole-directory `lrwxr-xr-x`, owner `villalj`, group `staff`, relative link | `no`                                                                                                                 |
| `~/.config/BetterDisplay/config.backup.*.plist` | `no`   | `no`    | `no`    | `target`         | `scripts/betterdisplay.zsh` creates a timestamped backup before import; no matching file exists in the current source or target scan.                                                                      | `active-global`    | `preserve`        | `~/.config/BetterDisplay/config.backup.*.plist` | Runtime regular files; preserve normal user ownership and mode              | `yes` — exported BetterDisplay settings can repeat machine-specific identifiers                                      |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/BetterDisplay
# no output

git check-ignore -v .config/BetterDisplay/config.plist .config/BetterDisplay/README.md
# no output; both source files are tracked and not Git-ignored
```

The source boundary contains exactly the two tracked files listed above. The
target is currently the same whole-directory Stow link, so it has no separate
target-only files. The `config.backup.*.plist` pattern is a future runtime
boundary: preserve backups at the physical target after cutover and remove
any such files from the repository source if they appear there.

The binary plist contains five filtered identifier-related fields, including
`storedIdentifiers@Display:2` and UUID fields. It records display hardware
identity and display-specific state. The README warns that UUIDs and
`storedIdentifier@(...)` data may not transfer between Macs or macOS
installations. Values were not printed.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/BetterDisplay` -> `../dev/personal/dot/.config/BetterDisplay`; `config.plist` and `README.md` resolve through the source directory
- Old owner cleanup command: `test -L "$HOME/.config/BetterDisplay" && test "$(readlink "$HOME/.config/BetterDisplay")" = "../dev/personal/dot/.config/BetterDisplay" && unlink "$HOME/.config/BetterDisplay"`
- New owner dry-run command: `mise -E betterdisplay bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E betterdisplay bootstrap dotfiles apply --yes`
- Duplicate-owner check: `! stow -nvR . 2>&1 | grep -F -- '.config/BetterDisplay' && mise -E betterdisplay bootstrap dotfiles status | grep -F -- '.config/BetterDisplay/config.plist'`
- Target-content disposition check: `test -d "$HOME/.config/BetterDisplay" && test -L "$HOME/.config/BetterDisplay/config.plist" && ! test -e "$HOME/.config/BetterDisplay/README.md" && ! find -P "$HOME/.config/BetterDisplay" -mindepth 1 -maxdepth 1 ! -name 'config.plist' ! -name 'config.backup.*.plist' -print -quit | grep -q .`
- Relative-link check: `python3 -c 'from pathlib import Path; p = Path.home() / ".config/BetterDisplay/config.plist"; assert p.is_symlink() and not p.readlink().is_absolute() and p.resolve() == Path.home() / "dev/personal/dot/home/.config/BetterDisplay/config.plist"'`

## Coupling

- Scripts:
  - `scripts/init.zsh` sets `__manage_betterdisplay` for `-d|--display` and sources `scripts/betterdisplay.zsh`.
  - `scripts/betterdisplay.zsh` currently sets `__config_dir="$__dotfiles_dir/.config/BetterDisplay"` and `__config_file="$__config_dir/config.plist"`.
  - On export, the script creates the source directory if needed, runs `defaults export pro.betterdisplay.BetterDisplay /tmp/BetterDisplay_export.plist`, then moves the temporary export over `__config_file`. After migration, export must write to the tracked `~/dev/personal/dot/home/` source or its resolved source path, not replace the deployed mise symlink.
  - On import, the script reads `__config_file`; if BetterDisplay is running, it asks for confirmation, quits the app with `osascript`, waits two seconds, and runs `defaults import pro.betterdisplay.BetterDisplay "$__config_file"`.
  - Before import, `__backup_current_settings` writes `config.backup.$(date +%Y%m%d_%H%M%S).plist` under the current `__config_dir`. This must change to the physical target runtime directory so backups remain target-only and never enter `~/dev/personal/dot/home/`.
- Environment variables:
  - `__dotfiles_dir` is supplied by the dynamic scope of `scripts/init.zsh`; `__manage_betterdisplay` controls whether the script runs.
  - `HOME` is used to locate `~/Applications/BetterDisplay.app` and the installed target.
  - `DOT_PROFILE` selects the mise profile, while `MISE_ENV=betterdisplay` or `mise -E betterdisplay` selects this module for focused validation.
- Includes or external paths:
  - Bundle identifier: `pro.betterdisplay.BetterDisplay`.
  - App locations: `/Applications/BetterDisplay.app` and `~/Applications/BetterDisplay.app`.
  - External commands: `defaults`, `pgrep`, and `osascript`.
  - Current export scratch path: `/tmp/BetterDisplay_export.plist`; it must remain transient and must not become a tracked source.
- Other modules:
  - `MIG-MODULE-mise` supplies the mise control plane and is the direct dependency.
  - The `packages` boundary installs the `brew-cask:betterdisplay` package declared in `.config/mise/conf.d/bootstrap-packages.toml`.
- User-facing behavior:
  - Preserve `./scripts/init.zsh -d` export/import behavior, the installed-app check, the running-app confirmation, the pre-import backup, and the display-identifier warning.
  - Preserve `config.plist` as the only mise-managed target file.
  - Preserve `README.md` only in the repository source; remove it from the deployed target.
  - Preserve `config.backup.*.plist` only as target-local runtime state; remove or exclude any repository copy.

## Validation

- Syntax or source checks:
  - `zsh -n scripts/betterdisplay.zsh`
  - `file .config/BetterDisplay/config.plist && plutil -lint .config/BetterDisplay/config.plist`
  - `git ls-files --error-unmatch .config/BetterDisplay/config.plist .config/BetterDisplay/README.md`
- Focused test:
  - `tests/scripts/test_betterdisplay.zsh`
- Target smoke test:
  - `test -L "$HOME/.config/BetterDisplay/config.plist" && plutil -lint "$HOME/.config/BetterDisplay/config.plist" && test ! -e "$HOME/.config/BetterDisplay/README.md"`
  - Defer an actual import/export smoke test until BetterDisplay can be safely stopped and the target backup disposition is verified.
- Security or token check:
  - `git grep -nE 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|password|token|secret' -- .config/BetterDisplay scripts/betterdisplay.zsh`
  - Do not dump or decode the plist; use `plutil -lint`, metadata, checksum, and filtered identifier-key inspection only.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/BetterDisplay/config.plist`, `~/dev/personal/dot/home/.config/BetterDisplay/config.plist`, the current `~/.config/BetterDisplay` symlink target, and any `~/.config/BetterDisplay/config.backup.*.plist` files outside the repository.
- Rollback dry run:
  - `mise -E betterdisplay bootstrap dotfiles unapply --dry-run && stow -nvR .`
- Rollback apply:
  - `mise -E betterdisplay bootstrap dotfiles unapply --yes && stow -vR .`
- Stop condition:
  - Stop if the current target is not the recorded relative Stow link, if the target contains unmanaged files other than preserved `config.backup.*.plist` runtime files, if mise proposes a README link, if export would replace a mise symlink, or if any command reports a source/target conflict.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/BetterDisplay/config.plist` and `.config/BetterDisplay/README.md` are the only tracked, non-ignored source files.
  - `~/.config/BetterDisplay` is the expected relative whole-directory Stow symlink, and its source and target `config.plist` hashes match.
  - The roadmap specifies `~/dev/personal/dot/home/.config/BetterDisplay/config.plist` as the mise-managed source/target pair, `symlink-each`, and a repository-only README with no deployed symlink.
  - The README documents UUID and `storedIdentifier@(...)` display-specific settings; filtered plist inspection confirms identifier fields without exposing plist contents.
- Residual risk:
  - `medium`; display identifiers and EDID data are machine-specific, and the current script writes both the exported config and pre-import backups through the Stow source directory. The script path split and target-only backup rule must be implemented before cutover.
- Open blocker:
  - Ownership cutover still requires explicit migration approval and a focused script/test update. Do not apply mise or remove the current Stow link from this inventory task.
