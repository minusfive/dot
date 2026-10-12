# Module Inventory: `git`

## Metadata

- Module key: `git`
- Story key: `MIG-MODULE-git`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/git.md`
- Current declaration: `.stowrc` (`--target=~`) and `scripts/symlink.zsh` (`stow -vR .`)
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.git.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/git`
- Mise mode: `symlink-each`
- Environment selector: `git`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path          | Tracked | Ignored | Current owner | Current target         | Target disposition | New source path                              | New target             | New mode       | Notes                                                                                                                     |
| -------------------- | ------- | ------- | ------------- | ---------------------- | ------------------ | -------------------------------------------- | ---------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `.config/git/config` | `yes`   | `no`    | `Stow`        | `~/.config/git/config` | `migrate`          | `~/dev/personal/dot/home/.config/git/config` | `~/.config/git/config` | `symlink-each` | Global Git configuration with conditional external includes, SSH signing, delta integration, aliases, and color behavior. |
| `.config/git/ignore` | `yes`   | `no`    | `Stow`        | `~/.config/git/ignore` | `migrate`          | `~/dev/personal/dot/home/.config/git/ignore` | `~/.config/git/ignore` | `symlink-each` | Git's global excludes file; it is not a repository `.gitignore` and includes local mise/config variants.                  |

The source manifest is exactly the two tracked files above. The ignored-file
and non-ignored untracked-file queries returned no paths.

## Local and runtime inventory

| Path                                                     | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                | Classification   | Required action | Runtime destination                                      | Metadata to preserve                                                                                    | Secret or sensitive data |
| -------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------- | --------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/git`                                            | `no`   | `no`    | `no`    | `historical`     | Retired Stow source boundary; files moved to `home/.config/git`.                                                   | `historical`     | `remove`        | `none`                                                   | `retired source path`                                                                                   | `no`                     |
| `.config/git/config`                                     | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; Git config moved to `home/.config/git/config`.                                                | `historical`     | `remove`        | `~/.config/git/config`                                   | `retired source path`                                                                                   | `no`                     |
| `.config/git/ignore`                                     | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; global excludes moved to `home/.config/git/ignore`.                                           | `historical`     | `remove`        | `~/.config/git/ignore`                                   | `retired source path`                                                                                   | `no`                     |
| `~/.config/git`                                          | `yes`  | `no`    | `no`    | `target`         | Physical directory with two relative per-file links to the mise source.                                            | `active-global`  | `preserve`      | `~/.config/git`                                          | Physical directory, owner/group `villalj:staff`, mode 0755                                              | `no`                     |
| `~/.config/git/<target-only>`                            | `no`   | `no`    | `no`    | `target`         | The target file manifest contains only `config` and `ignore`, both resolved from the Stow source.                  | `not-applicable` | `none`          | `none`                                                   | `none`                                                                                                  | `no`                     |
| `~/dev/work/.gitconfig`                                  | `yes`  | `no`    | `no`    | `other`          | Included for repositories under `~/dev/work/`; the file exists but its contents are not part of this boundary.     | `active-global`  | `preserve`      | `~/dev/work/.gitconfig`                                  | Regular file `0644`, owner/group `villalj:staff`; preserve without copying into the repository.         | `unknown`                |
| `~/dev/personal/.gitconfig`                              | `yes`  | `no`    | `no`    | `other`          | Included for repositories under `~/dev/personal/`; the file exists but its contents are not part of this boundary. | `active-global`  | `preserve`      | `~/dev/personal/.gitconfig`                              | Regular file `0644`, owner/group `villalj:staff`; preserve without copying into the repository.         | `unknown`                |
| `~/Notes/Work/.gitconfig`                                | `no`   | `no`    | `no`    | `other`          | Conditional include path is configured but absent on this machine.                                                 | `not-applicable` | `none`          | `none`                                                   | `none`                                                                                                  | `no`                     |
| `~/Notes/Personal/.gitconfig`                            | `no`   | `no`    | `no`    | `other`          | Conditional include path is configured but absent on this machine.                                                 | `not-applicable` | `none`          | `none`                                                   | `none`                                                                                                  | `no`                     |
| `/Applications/1Password.app/Contents/MacOS/op-ssh-sign` | `yes`  | `no`    | `no`    | `other`          | Configured by `gpg.ssh.program`; the executable exists and is executable.                                          | `active-global`  | `preserve`      | `/Applications/1Password.app/Contents/MacOS/op-ssh-sign` | Executable file `0755`, owner/group `villalj:staff`; application-owned and outside the source boundary. | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/git
git check-ignore -v .config/git/config
git check-ignore -v .config/git/ignore
```

The ignored-file query returned no paths. The two `git check-ignore` commands
returned no matches because both source files are tracked. The global ignore
file itself ignores temporary files, generated files, local mise/config
variants, and other tool or repository runtime paths. These are Git ignore
rules, not additional source files for this module. Do not inspect or print
the contents of external include files.

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links`
- Current target manifest path: `~/.config/git`
- Old owner cleanup command: `test -L "$HOME/.config/git" && test "$(readlink "$HOME/.config/git")" = "../dev/personal/dot/.config/git" && rm "$HOME/.config/git"`
- New owner dry-run command: `mise -E git bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E git bootstrap dotfiles apply --yes`
- Duplicate-owner check: `test -z "$(stow -nvR . 2>&1 | grep -F -- '.config/git' || true)" && mise -E git bootstrap dotfiles status | grep -F -- '.config/git'`
- Target-content disposition check: `test -d "$HOME/.config/git" && test ! -L "$HOME/.config/git" && test -L "$HOME/.config/git/config" && test -L "$HOME/.config/git/ignore" && test "$(realpath "$HOME/.config/git/config")" = "$(realpath "$HOME/dev/personal/dot/home/.config/git/config")" && test "$(realpath "$HOME/.config/git/ignore")" = "$(realpath "$HOME/dev/personal/dot/home/.config/git/ignore")"`
- Relative-link check: `for path in "$HOME/.config/git/config" "$HOME/.config/git/ignore"; do case "$(readlink "$path")" in /*) exit 1;; esac; done`

The baseline `stow -nvR .` reports `UNLINK: .config/git` followed by
`LINK: .config/git => ../dev/personal/dot/.config/git`, confirming the current
Stow ownership. Remove only the confirmed parent symlink after the new source
exists and the mise dry run names the intended per-file targets.

## Coupling

- Scripts:
  - `scripts/symlink.zsh` runs `stow -vR .`; it must not recreate `.config/git` after the old source is retired or excluded.
  - `scripts/mise.zsh` already runs `mise bootstrap dotfiles apply --yes`; no new initialization phase is required for this boundary.
  - `tests/scripts/test_mise_config.zsh` currently verifies the Stow deployment and Git ignore behavior; the planned module test must add mise ownership assertions.
- Environment variables:
  - `.zshenv` sets `XDG_CONFIG_HOME="$HOME/.config"`, which supplies the target root.
  - No repository override for `GIT_CONFIG_GLOBAL` was found; Git uses the XDG configuration path and its default global excludes path.
  - `MISE_ENV=git` or `mise -E git` is the scoped selector for module validation after the declaration exists.
- Includes or external paths:
  - `.config/git/config` conditionally includes `~/dev/work/.gitconfig` for `~/dev/work/` and `~/dev/personal/.gitconfig` for `~/dev/personal/`.
  - It also records configured but currently absent paths `~/Notes/Work/.gitconfig` and `~/Notes/Personal/.gitconfig`.
  - The unconditional delta include is `~/.config/delta/themes/catppuccin.gitconfig`; preserve the `MIG-MODULE-delta` target and include path.
  - SSH signing uses `gpg.format = ssh` and the application-owned executable `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`; `commit.gpgsign` and `tag.gpgsign` remain enabled. No signing key or credential value is recorded here.
- Other modules:
  - `MIG-MODULE-mise` provides the control plane and existing dotfiles bootstrap phase.
  - `MIG-MODULE-delta` supplies the included Catppuccin delta configuration.
  - `MIG-MODULE-1password` supplies the application that owns the configured SSH signing command; Git does not own that application path.
- User-facing behavior:
  - Preserve Git's pull, push, rebase, alias, color, delta, filter, signing, and external include behavior.
  - Preserve global ignore behavior for local mise/config variants; this file must remain deployed as Git's global excludes file rather than becoming a repository `.gitignore`.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch home/.config/git/config home/.config/git/ignore`
  - `git config --file home/.config/git/config --list >/dev/null`
  - `test -s home/.config/git/ignore`
  - After the source move: `git ls-files --error-unmatch ~/dev/personal/dot/home/.config/git/config ~/dev/personal/dot/home/.config/git/ignore`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_git.zsh` (planned module test; not
    present in the current tree; it must assert the
    Git source manifest, `symlink-each` declaration, target ownership, external
    include paths, signing executable path, global ignore rules, and runtime
    exclusions).
- Target smoke test:
  - `test "$(git config --global --get gpg.format)" = ssh && test "$(git config --global --get commit.gpgsign)" = true && test "$(git config --global --get tag.gpgsign)" = true && test -x "$(git config --global --get gpg.ssh.program)" && git check-ignore -q --no-index mise.local.toml && git check-ignore -q --no-index config.personal.local.toml`
- Security or token check:
  - `! rg -n -i '(api[_-]?key|token|secret|credential|private[[:space:]_-]?key|auth[.]db)' home/.config/git`
  - `git ls-files --others --ignored --exclude-standard -- home/.config/git`
  - Do not print values from external include files or any credential-bearing Git configuration.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/git/config` and `.config/git/ignore`
  - The exact `readlink "$HOME/.config/git"` result and source/target checksums
  - The existence and executable metadata of `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`
  - Do not copy external include contents into the repository.
- Rollback dry run:
  - `mise -E git bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - After restoring the old source and declaration, run `mise -E git bootstrap dotfiles unapply --yes` followed by `stow -vR .`
- Stop condition:
  - Stop if the target is not the recorded Stow symlink before cleanup, if target-only files appear, if any external include or signing path changes unexpectedly, if Git ignore behavior changes, if a sensitive value appears in the new source, or if mise and Stow both claim the target.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `module-registry.toml` assigns `git` to `MIG-MODULE-git` with dependency
    `MIG-MODULE-mise`.
  - `.config/git/config` contains four conditional include paths, the delta include, SSH signing settings, and enabled commit/tag signing; the signing executable exists.
  - `.config/git/ignore` is active through the current target and the existing mise configuration test verifies its local-file ignore rules.
  - The target is the confirmed whole-directory relative Stow symlink `../dev/personal/dot/.config/git`.
- Residual risk:
  - Git behavior depends on external include files and an application-owned signing command. The new per-file links must preserve the exact target paths while keeping those external files and application runtime outside tracked sources.
- Open blocker:
  - None. The target now uses the approved mise `symlink-each` declaration and
    the external include and signing paths remain outside this boundary.
