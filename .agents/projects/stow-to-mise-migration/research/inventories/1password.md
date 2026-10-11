# Module Inventory: `1password`

## Metadata

- Module key: `1password`
- Story key: `MIG-MODULE-1password`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/1password.md`
- Current declaration: `.config/1Password/ssh/agent.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.1password.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/1Password`
- Mise mode: `symlink-each`
- Environment selector: `1password` in both profile branches
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                        | Tracked | Ignored | Current owner | Current target                       | Target disposition | New source path                                            | New target                           | New mode       | Notes                                                                                                                                                                   |
| ---------------------------------- | ------- | ------- | ------------- | ------------------------------------ | ------------------ | ---------------------------------------------------------- | ------------------------------------ | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/1Password/ssh/agent.toml` | `yes`   | `no`    | `stow`        | `~/.config/1Password/ssh/agent.toml` | `migrate`          | `~/dev/personal/dot/home/.config/1Password/ssh/agent.toml` | `~/.config/1Password/ssh/agent.toml` | `symlink-each` | Tracked 1Password SSH agent configuration. It contains vault references, which are intentionally not reproduced here; no private-key material is stored in this source. |

## Local and runtime inventory

| Path                                                                                                                        | Exists | Tracked | Ignored | Current location  | Active use evidence                                                                        | Classification   | Required action | Runtime destination                                                | Metadata to preserve                                                                                   | Secret or sensitive data                                                  |
| --------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ----------------- | ------------------------------------------------------------------------------------------ | ---------------- | --------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `.config/1Password/ssh/agent.toml`                                                                                          | `yes`  | `yes`   | `no`    | `repo`            | The current target resolves to this source; the file configures the 1Password SSH agent.   | `active-global`  | `move`          | `none`                                                             | Regular file mode `0644`; preserve source text without exposing vault references.                      | `yes` — vault references; no credentials or private-key contents observed |
| `~/.config/1Password`                                                                                                       | `yes`  | `no`    | `no`    | `target`          | A whole-directory symlink resolves to the Stow source boundary.                            | `active-global`  | `remove`        | `none`                                                             | Preserve the recorded relative link target until the mise cutover is ready.                            | `yes` — resolves to the agent configuration                               |
| `~/.ssh/1Password/config`                                                                                                   | `yes`  | `no`    | `no`    | `other`           | Included by `~/.ssh/config`; generated or maintained outside this repository.              | `active-global`  | `preserve`      | `~/.ssh/1Password/config`                                          | Regular file mode `0600`; keep outside tracked sources.                                                | `yes` — agent configuration and identity metadata                         |
| `~/.ssh/1Password/*.pub`                                                                                                    | `yes`  | `no`    | `no`    | `other`           | Public-key metadata is present beside the included SSH agent configuration.                | `active-global`  | `preserve`      | `~/.ssh/1Password/*.pub`                                           | Regular file mode `0600`; do not copy fingerprint-bearing names or contents into the inventory.        | `no` — public-key metadata only                                           |
| `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`                                                          | `yes`  | `no`    | `no`    | `other`           | Referenced by `~/.ssh/config` and `.config/zsh/.zshrc`; the path is an active Unix socket. | `active-global`  | `exclude`       | `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` | Socket mode `0600`; tool-owned runtime state must remain outside the repository and mise declarations. | `yes` — live SSH-agent capability                                         |
| `~/Library/Application Support/1Password/`                                                                                  | `yes`  | `no`    | `no`    | `other`           | 1Password application support state exists outside the configured dotfile boundary.        | `active-global`  | `exclude`       | `~/Library/Application Support/1Password/`                         | Tool-owned directory mode `0700`; preserve application ownership and contents.                         | `yes` — tool-owned runtime state may contain credentials                  |
| `~/Library/Group Containers/2BUA8C4S2C.com.1password/`                                                                      | `yes`  | `no`    | `no`    | `other`           | The 1Password group-container runtime directory contains the SSH agent socket.             | `active-global`  | `exclude`       | `~/Library/Group Containers/2BUA8C4S2C.com.1password/`             | Preserve tool-owned runtime directory and socket permissions.                                          | `yes` — tool-owned runtime state                                          |
| ``Private-key filename candidates under `.config/1Password` and `~/.config/1Password` (`id_*`, `*.pem`, `*.key`, `*.ppk`)`` | `no`   | `no`    | `no`    | `repo and target` | Filename-only scan found no private-key candidates in the source or resolved target.       | `not-applicable` | `exclude`       | `none`                                                             | No candidate metadata to preserve.                                                                     | `no`                                                                      |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/1Password
git check-ignore -v <path>
```

No ignored paths were found under `.config/1Password`. The SSH agent socket,
application support state, group-container state, and `~/.ssh/1Password`
artifacts are runtime-managed paths outside the repository. No private-key
file contents were inspected or recorded.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/1Password -> ../dev/personal/dot/.config/1Password`
- Old owner cleanup command: `test "$(readlink "$HOME/.config/1Password")" = "../dev/personal/dot/.config/1Password" && rm "$HOME/.config/1Password"`
- New owner dry-run command: `MISE_ENV=work mise bootstrap dotfiles apply --dry-run`
- New owner apply command: `MISE_ENV=work mise bootstrap dotfiles apply --yes`
- Duplicate-owner check: `if stow -nvR . 2>&1 | grep -Fq '.config/1Password'; then exit 1; fi; grep -R -nF '~/.config/1Password' ~/dev/personal/dot/home/.config/mise/conf.d 2>/dev/null`
- Target-content disposition check: `test -d "$HOME/.config/1Password" && test ! -L "$HOME/.config/1Password" && python3 -c 'from pathlib import Path; target = Path.home()/".config/1Password/ssh/agent.toml"; source = Path.home()/"dev/personal/dot/home/.config/1Password/ssh/agent.toml"; assert target.is_symlink() and target.resolve() == source'`
- Relative-link check: `test -L "$HOME/.config/1Password/ssh/agent.toml" && case "$(readlink "$HOME/.config/1Password/ssh/agent.toml")" in /*) exit 1;; *) exit 0;; esac`

## Coupling

- Scripts:
  - `scripts/mise.zsh` already applies the mise dotfiles phase; no new initialization phase is required.
  - `scripts/symlink.zsh` applies the current Stow owner with `stow -vR .`; remove or exclude the old source only after the mise owner passes its checks.
- Environment variables:
  - `.config/zsh/.zshrc` exports `SSH_AUTH_SOCK` to the external 1Password agent socket.
  - `MISE_ENV` selects the mise environment while applying the new dotfile declaration; this module has no module-specific selector.
- Includes or external paths:
  - `.ssh/config` sets the external 1Password agent socket and includes `~/.ssh/1Password/config`.
  - `.config/git/config` uses the installed 1Password SSH signing executable.
  - `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` is runtime-owned and must not be declared.
- Other modules:
  - `MIG-MODULE-mise` must establish the mise control plane before this module.
  - Git and Zsh consume the external agent runtime but do not own `~/.config/1Password`.
- User-facing behavior:
  - Preserve the 1Password SSH agent configuration and its vault references without copying private keys, credentials, or runtime state into tracked sources.
  - Replace the current whole-directory Stow link with a physical target directory containing mise-managed per-file links.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch .config/1Password/ssh/agent.toml`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/1password.md`
  - `test -f .config/1Password/ssh/agent.toml`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_1password.zsh`
- Target smoke test:
  - `test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" && ssh -G github.com >/dev/null`
  - `test -f "$HOME/.ssh/1Password/config"`
- Security or token check:
  - `! grep -REq 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY' .config/1Password ~/dev/personal/dot/home/.config/1Password 2>/dev/null`
  - `! grep -REiq '(^|[^[:alnum:]])(token|password|secret|credential)[[:space:]]*=' .config/1Password ~/dev/personal/dot/home/.config/1Password 2>/dev/null`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/1Password/ssh/agent.toml`
  - The current target link manifest from `readlink "$HOME/.config/1Password"`
  - The external `~/.ssh/1Password` configuration and 1Password runtime paths
  - The pre-transition output of `stow -nvR .` and `mise bootstrap dotfiles apply --dry-run`
- Rollback dry run:
  - Restore the Stow source and target shape, then run `stow -nvR .`
- Rollback apply:
  - Restore the whole-directory target link, then run `stow -vR .`
- Stop condition:
  - Stop if the target contains unexpected files, the mise dry run proposes deletion or a conflicting owner, the SSH agent socket is unavailable, or any private-key or tool-runtime file would enter the new source.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/1Password/ssh/agent.toml`
  - `.stowrc`
  - `.ssh/config`
  - `.config/zsh/.zshrc`
  - `scripts/mise.zsh`
  - `.agents/projects/stow-to-mise-migration/module-registry.toml`
- Residual risk:
  - The current target is a whole-directory Stow symlink. It must be detached before mise can create a physical directory with per-file links. The agent configuration contains vault references, and the external 1Password runtime must remain outside tracked sources.
- Open blocker:
  - `none for inventory; migration execution remains pending explicit approval and the module-focused test`
