# Module Inventory: `gh`

## Metadata

- Module key: `gh`
- Story key: `MIG-MODULE-gh`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/gh.md`
- Current declaration: `.config/mise/conf.d/bootstrap-gh.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.gh.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~/.config/gh/personal`
- Mise mode: `symlink`
- Environment selector: `gh`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                             | Tracked | Ignored | Current owner | Current target                    | Target disposition | New source path                                         | New target                        | New mode    | Notes                                                                                                                |
| ------------------------------------------------------- | ------- | ------- | ------------- | --------------------------------- | ------------------ | ------------------------------------------------------- | --------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------- |
| `~/dev/personal/dot/home/.config/gh/personal/hosts.yml` | `yes`   | `no`    | `mise`        | `~/.config/gh/personal/hosts.yml` | `migrate`          | `~/dev/personal/dot/home/.config/gh/personal/hosts.yml` | `~/.config/gh/personal/hosts.yml` | `symlink`   | Tracked GitHub hosts source; preserve its token-free invariant and replace the legacy `[bootstrap.files]` ownership. |
| `~/.config/gh/personal`                                 | `no`    | `no`    | `mise`        | `~/.config/gh/personal`           | `preserve`         | `none`                                                  | `~/.config/gh/personal`           | `bootstrap` | Existing `[bootstrap.directories]` resource; retain directory mode `0755` separately from the symlinked file.        |

## Local and runtime inventory

| Path                                                    | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                            | Classification  | Required action   | Runtime destination               | Metadata to preserve                                 | Secret or sensitive data                                   |
| ------------------------------------------------------- | ------ | ------- | ------- | ---------------- | -------------------------------------------------------------------------------------------------------------- | --------------- | ----------------- | --------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------- |
| `~/dev/personal/dot/home/.config/gh/personal/hosts.yml` | `yes`  | `yes`   | `no`    | `repo`           | Current `[bootstrap.files]` source; focused test checks the token-free invariant.                              | `active-global` | `preserve`        | `~/.config/gh/personal/hosts.yml` | `0644`, `villalj:staff`                              | `yes` (credential-bearing boundary; token-free source)     |
| `~/.config/gh/personal`                                 | `yes`  | `no`    | `no`    | `target`         | Current `[bootstrap.directories]` target reports directory mode `0755`.                                        | `active-global` | `none`            | `~/.config/gh/personal`           | `0755`, `villalj:staff`, physical directory          | `no`                                                       |
| `~/.config/gh/personal/hosts.yml`                       | `yes`  | `no`    | `no`    | `target`         | Standard personal `gh` configuration path; current target is a regular file and matches the repository source. | `active-global` | `copy-then-erase` | `~/.config/gh/personal/hosts.yml` | `0644`, `villalj:staff`, regular file before cutover | `yes` (credential-bearing boundary; do not print contents) |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

No ignored or non-ignored untracked files exist under `~/dev/personal/dot/home/.config/gh`.
`.stow-local-ignore` excludes `^/home`, so the source is outside GNU Stow's
managed source boundary. The repository has no `.gitignore` file, and
`git check-ignore -v --no-index` reports no match for the source paths.

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `physical directory` containing a regular `hosts.yml` file; neither target is currently a symlink
- Current target manifest path: `~/.config/gh/personal` and `~/.config/gh/personal/hosts.yml`
- Old owner cleanup command: `mise bootstrap unapply gh --dry-run`; after the dry run names `~/.config/gh/personal/hosts.yml`, apply with `mise bootstrap unapply gh --yes`
- New owner dry-run command: `mise -E gh bootstrap --only dotfiles --dry-run`
- New owner apply command: `mise -E gh bootstrap --only dotfiles --yes`
- Duplicate-owner check: `stow -nvR . 2>&1 | grep -E 'gh/personal|hosts\.yml'` must produce no GitHub target lines
- Target-content disposition check: `cmp -s ~/dev/personal/dot/home/.config/gh/personal/hosts.yml "$HOME/.config/gh/personal/hosts.yml"`
- Relative-link check: `test -L "$HOME/.config/gh/personal/hosts.yml" && test "$(realpath "$HOME/.config/gh/personal/hosts.yml")" = "$(realpath ~/dev/personal/dot/home/.config/gh/personal/hosts.yml)"`

## Coupling

- Scripts:
  - `scripts/mise.zsh` — no change; the existing mise dotfiles phase already applies selected dotfile declarations.
  - `tests/scripts/test_mise_bootstrap_gh.zsh` — update the focused assertions from `[bootstrap.files]` to the future `[dotfiles]` symlink entry while retaining the directory mode and token-free checks.
- Environment variables:
  - `GH_CONFIG_DIR` — rendered by `~/dev/personal/dot/home/dev/profile.mise.toml` as `~/.config/gh/<target profile>`, including `~/.config/gh/personal` for the personal profile.
- Includes or external paths:
  - `none`
- Other modules:
  - `MIG-MODULE-profiles` — future owner of the two profile templates currently colocated in `bootstrap-gh.toml`; preserve those resources when retiring the aggregate declaration.
- User-facing behavior:
  - `gh` must continue to use `~/.config/gh/personal/hosts.yml`; the directory remains mode `0755`, the file remains mode `0644`, and no OAuth token may enter the tracked source.

## Validation

- Syntax or source checks:
  - `git ls-files -- ~/dev/personal/dot/home/.config/gh/personal`
  - `test -f ~/dev/personal/dot/home/.config/gh/personal/hosts.yml`
  - `stat -c '%n|%F|%A|%U|%G' "$HOME/.config/gh/personal" "$HOME/.config/gh/personal/hosts.yml"`
- Focused test:
  - `zsh tests/scripts/test_mise_bootstrap_gh.zsh`
- Target smoke test:
  - `GH_CONFIG_DIR="$HOME/.config/gh/personal" gh auth status --hostname github.com` (run without printing host-file contents or tokens)
- Security or token check:
  - `! grep -qF 'oauth_token:' ~/dev/personal/dot/home/.config/gh/personal/hosts.yml`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - Keep `.config/mise/conf.d/bootstrap-gh.toml`, `~/dev/personal/dot/home/.config/gh/personal/hosts.yml`, and the physical target file until the legacy unapply dry run and new-owner dry run both name only the intended target. Preserve the `0755` directory metadata.
- Rollback dry run:
  - `mise dot unapply ~/.config/gh/personal/hosts.yml --dry-run`
  - `mise bootstrap files apply --dry-run`
- Rollback apply:
  - `mise dot unapply ~/.config/gh/personal/hosts.yml --yes`
  - `mise bootstrap files apply --yes`
- Stop condition:
  - Stop if either dry run names an unexpected target, the target contains changed or unmanaged content, the symlink resolves outside the recorded source, the token-free check fails, or Stow reports a GitHub target.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-gh.toml` declares the `0755` directory and `0644` file resources.
  - The current target is a physical directory with a regular file, and source and target compare equal without printing contents.
  - `zsh tests/scripts/test_mise_bootstrap_gh.zsh` passed and confirmed the current token-free invariant.
  - `~/dev/personal/dot/home/dev/profile.mise.toml` references the personal GitHub configuration through `GH_CONFIG_DIR`.
- Residual risk:
  - `hosts.yml` is a credential-bearing configuration boundary even though the tracked source currently has no `oauth_token:` marker. The current aggregate declaration also owns profile files that must remain available to `MIG-MODULE-profiles`.
- Open blocker:
  - Approval is pending. The legacy `[bootstrap.files]` resource cannot be removed with `mise dot unapply`; `mise bootstrap files` has no `unapply` subcommand. The current unscoped declaration makes `mise bootstrap unapply gh --dry-run` report no resources, so keep the legacy declaration available and stage it under the future `gh` environment. Then run that exact cleanup path followed by `mise bootstrap unapply gh --yes` only after the dry run names the intended target.
