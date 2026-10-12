# Module Inventory: `mise`

## Metadata

- Module key: `mise`
- Story key: `MIG-MODULE-mise`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/mise.md`
- Current declaration: `.config/mise/config.toml`, `.config/mise/miserc.toml`, `.config/mise/conf.d/*.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.mise.toml`
- Planning gate: `DEC-mise-control-plane-transition-mechanism`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/mise`
- Mise mode: `symlink-each`
- Environment selector: `mise`, with the `work` or `personal` profile environment
- Dependencies: `none`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                            | Tracked | Ignored | Current owner | Current target                                           | Target disposition | New source path                                                                | New target                                               | New mode  | Notes                                                                                                                                                                    |
| ------------------------------------------------------ | ------- | ------- | ------------- | -------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------ | -------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.config/mise/conf.d/bootstrap-ai.toml`                | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/bootstrap-ai.toml`                | `remove`           | `none`                                                                         | `none`                                                   | `none`    | Retired empty aggregate declaration; the AI entries now belong to the focused `module.*.toml` files.                                                                     |
| `.config/mise/conf.d/bootstrap-gh.toml`                | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/bootstrap-gh.toml`                | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/bootstrap-gh.toml`                | `~/.config/mise/conf.d/bootstrap-gh.toml`                | `symlink` | Preserve 0644, generated personal/work profile files, the GH config directory, and the token-free hosts source. Use explicit `~/dev/personal/dot/home/...` source paths. |
| `.config/mise/conf.d/bootstrap-packages.personal.toml` | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/bootstrap-packages.personal.toml` | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/bootstrap-packages.personal.toml` | `~/.config/mise/conf.d/bootstrap-packages.personal.toml` | `symlink` | Preserve 0644 and the personal package boundary. Verify profile selection before applying.                                                                               |
| `.config/mise/conf.d/bootstrap-packages.toml`          | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/bootstrap-packages.toml`          | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/bootstrap-packages.toml`          | `~/.config/mise/conf.d/bootstrap-packages.toml`          | `symlink` | Preserve 0644, shared Homebrew formulas/casks, and Mac App Store declarations. No credential values were found.                                                          |
| `.config/mise/conf.d/bootstrap-repos.toml`             | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/bootstrap-repos.toml`             | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/bootstrap-repos.toml`             | `~/.config/mise/conf.d/bootstrap-repos.toml`             | `symlink` | Preserve 0644 and all repository destinations. Review the SSH remote declaration without copying credentials.                                                            |
| `.config/mise/conf.d/tools.toml`                       | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/tools.toml`                       | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/tools.toml`                       | `~/.config/mise/conf.d/tools.toml`                       | `symlink` | Preserve 0644, pinned tool entries, and postinstall task names.                                                                                                          |
| `.config/mise/config.toml`                             | `yes`   | `no`    | `stow`        | `~/.config/mise/config.toml`                             | `migrate`          | `~/dev/personal/dot/home/.config/mise/config.toml`                             | `~/.config/mise/config.toml`                             | `symlink` | Preserve 0644, `env_file`, experimental settings, lockfile behavior, seven-day release age, and `relative_symlinks = true`.                                              |
| `.config/mise/mise.lock`                               | `yes`   | `no`    | `stow`        | `~/.config/mise/mise.lock`                               | `migrate`          | `~/dev/personal/dot/home/.config/mise/mise.lock`                               | `~/.config/mise/mise.lock`                               | `symlink` | Preserve 0644 and the 726-line global tool lock metadata. Do not regenerate during cutover. No credential-bearing fields were found.                                     |
| `.config/mise/miserc.toml`                             | `yes`   | `no`    | `stow`        | `~/.config/mise/miserc.toml`                             | `migrate`          | `~/dev/personal/dot/home/.config/mise/miserc.toml`                             | `~/.config/mise/miserc.toml`                             | `symlink` | Preserve 0644, the `DOT_PROFILE` profile template, the initial `work`/`personal` plus `mise` environment lists, and `env_conf_d = true`.                                 |
| `.config/mise/tasks/bootstrap.sh`                      | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/bootstrap.sh`                      | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/bootstrap.sh`                      | `~/.config/mise/tasks/bootstrap.sh`                      | `symlink` | Preserve executable mode 0755 and the GitHub CLI extension bootstrap behavior.                                                                                           |
| `.config/mise/tasks/git/worktree.ts`                   | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/git/worktree.ts`                   | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/git/worktree.ts`                   | `~/.config/mise/tasks/git/worktree.ts`                   | `symlink` | Preserve executable mode 0755 and the `../../utils/git.js` relative import.                                                                                              |
| `.config/mise/tasks/global-install-packages-all.sh`    | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-all.sh`    | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/global-install-packages-all.sh`    | `~/.config/mise/tasks/global-install-packages-all.sh`    | `symlink` | Preserve executable mode 0755 and the NPM, Python, and Ruby task chain.                                                                                                  |
| `.config/mise/tasks/global-install-packages-npm.sh`    | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-npm.sh`    | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/global-install-packages-npm.sh`    | `~/.config/mise/tasks/global-install-packages-npm.sh`    | `symlink` | Preserve executable mode 0755 and the global NPM package behavior.                                                                                                       |
| `.config/mise/tasks/global-install-packages-python.sh` | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-python.sh` | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/global-install-packages-python.sh` | `~/.config/mise/tasks/global-install-packages-python.sh` | `symlink` | Preserve executable mode 0755 and the global Python package behavior.                                                                                                    |
| `.config/mise/tasks/global-install-packages-ruby.sh`   | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-ruby.sh`   | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/global-install-packages-ruby.sh`   | `~/.config/mise/tasks/global-install-packages-ruby.sh`   | `symlink` | Preserve executable mode 0755 and the global Ruby gem behavior.                                                                                                          |
| `.config/mise/tasks/lint-skill-index.zsh`              | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/lint-skill-index.zsh`              | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/lint-skill-index.zsh`              | `~/.config/mise/tasks/lint-skill-index.zsh`              | `symlink` | Preserve executable mode 0755, repository-root discovery, and root/home skill-index validation.                                                                          |
| `.config/mise/tasks/md/preview.ts`                     | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/md/preview.ts`                     | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/md/preview.ts`                     | `~/.config/mise/tasks/md/preview.ts`                     | `symlink` | Preserve executable mode 0755 and the task behavior. Keep `tmp/md-preview/instances.json` as ignored project runtime state outside the source tree.                      |
| `.config/mise/tasks/pr/sync.ts`                        | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/pr/sync.ts`                        | `migrate`          | `~/dev/personal/dot/home/.config/mise/tasks/pr/sync.ts`                        | `~/.config/mise/tasks/pr/sync.ts`                        | `symlink` | Preserve executable mode 0755, GitHub CLI calls, process environment forwarding, and the `../../utils/git.js` relative import.                                           |
| `.config/mise/utils/git.ts`                            | `yes`   | `no`    | `stow`        | `~/.config/mise/utils/git.ts`                            | `migrate`          | `~/dev/personal/dot/home/.config/mise/utils/git.ts`                            | `~/.config/mise/utils/git.ts`                            | `symlink` | Preserve 0644 and the shared utility required by `git:worktree` and `pr:sync`.                                                                                           |

The ignored-inclusive source manifest was empty:

```bash
git ls-files --others --ignored --exclude-standard -- .config/mise
```

No source candidate matched `git check-ignore -v <path>`. The source tree
contains 18 tracked regular files and no ignored local variant. The target
manifest contains the same 18 active source files after the empty aggregate
declaration was retired.

## Local and runtime inventory

| Path                                                                                  | Exists | Tracked | Ignored | Current location | Active use evidence                                                                         | Classification     | Required action   | Runtime destination                                     | Metadata to preserve                                                                           | Secret or sensitive data |
| ------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------- | ------------------ | ----------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/mise`                                                                        | `yes`  | `no`    | `no`    | `repo`           | `~/.config/mise` resolves to this directory                                                 | `active-global`    | `copy-then-erase` | `~/.config/mise`                                        | Directory 0755; child modes are 0644 or 0755 as listed above                                   | `no`                     |
| `~/.config/mise`                                                                      | `yes`  | `no`    | `no`    | `target`         | `readlink` returns `../dev/personal/dot/.config/mise`                                       | `active-global`    | `remove`          | `~/.config/mise` physical directory with per-file links | Current relative parent link is `lrwxr-xr-x`; detach only after source and dry-run checks pass | `no`                     |
| `~/.config/mise/{mise,mise.*.local,miserc,miserc.*.local,config,config.*.local}.toml` | `no`   | `no`    | `yes`   | `target`         | Global Git ignore patterns in `~/.config/git/ignore` cover these names                      | `not-applicable`   | `exclude`         | `none`                                                  | Keep local files outside repository sources and declarations                                   | `unknown`                |
| `~/dev/personal/dot/home/.config/mise`                                                | `no`   | `no`    | `no`    | `repo`           | Planned source root; no destination exists yet                                              | `not-applicable`   | `copy-then-erase` | `~/.config/mise`                                        | Create 0755 and preserve child source modes                                                    | `no`                     |
| `~/dev/personal/dot/home/dev/profile.mise.toml`                                       | `yes`  | `yes`   | `no`    | `repo`           | `bootstrap-gh.toml` renders it for both workspace profiles                                  | `active-global`    | `preserve`        | `~/dev/personal/mise.toml`, `~/dev/work/mise.toml`      | Source is 0644; generated files are 0644                                                       | `no`                     |
| `~/dev/personal/mise.toml`, `~/dev/work/mise.toml`                                    | `yes`  | `no`    | `no`    | `target`         | `scripts/mise.zsh` trusts both paths after `bootstrap.files apply`                          | `active-global`    | `preserve`        | Same paths                                              | Generated regular files are 0644; retain template output and do not replace with links         | `no`                     |
| `.mise`                                                                               | `yes`  | `yes`   | `no`    | `repo`           | `.mise/config.toml`, `.mise/conf.d/*`, and `.mise/mise.lock` drive repository tasks         | `active-repo-only` | `preserve`        | Repository `.mise`                                      | Directory 0755; tracked files 0644                                                             | `no`                     |
| `.mise/mise.lock`                                                                     | `yes`  | `yes`   | `no`    | `repo`           | `tests/scripts/test_mise_config.zsh` requires the project lockfile                          | `active-repo-only` | `preserve`        | Repository `.mise/mise.lock`                            | File 0644; keep separate from the global lockfile                                              | `no`                     |
| `tmp/md-preview/instances.json`                                                       | `yes`  | `no`    | `yes`   | `repo`           | `tasks/md/preview.ts` uses `tmp/md-preview` for preview process state                       | `active-repo-only` | `exclude`         | Same ignored project runtime path                       | File 0644; preserve runtime state only in ignored storage                                      | `yes`                    |
| `$XDG_STATE_HOME/minusfive/profile`                                                   | `yes`  | `no`    | `no`    | `other`          | `scripts/functions.zsh` reads and writes the persisted `work` or `personal` selector        | `active-global`    | `preserve`        | Same state path                                         | File 0644; value withheld from this inventory                                                  | `no`                     |
| `.config/git/ignore`                                                                  | `yes`  | `yes`   | `no`    | `repo`           | Global ignore rules cover mise local variants; the focused test validates Stow installation | `active-global`    | `preserve`        | `~/.config/git/ignore`                                  | File 0644; keep local-variant patterns outside repository-local ignore rules                   | `no`                     |
| `.stowrc`                                                                             | `yes`  | `yes`   | `no`    | `repo`           | Sets the Stow target to `$HOME`                                                             | `active-repo-only` | `preserve`        | `none`                                                  | File 0644; retain for remaining Stow boundaries                                                | `no`                     |
| `.stow-local-ignore`                                                                  | `yes`  | `yes`   | `no`    | `repo`           | Excludes `.mise` and `home`, but not the current `.config/mise` source                      | `active-repo-only` | `preserve`        | `none`                                                  | File 0644; add a narrow boundary exclusion only if the old source remains during cutover       | `no`                     |

The target has no physical local variants, extra databases, WAL files, history
files, authentication files, or credential-named files. The global config
references `.env`, but no `.env` candidate exists under `.config/mise` or the
target. Do not copy any external `.env` file into the new source.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/mise` -> `../dev/personal/dot/.config/mise`; verify with `readlink "$HOME/.config/mise"` and the ignored-inclusive manifests above.
- Old owner cleanup command:

  ```bash
  test "$(readlink "$HOME/.config/mise")" = "../dev/personal/dot/.config/mise" &&
    rm "$HOME/.config/mise"
  ```

  Run this only after the copied `~/dev/personal/dot/home/.config/mise` source exists, the
  target-scoped mise dry run names only the intended target, and no local file
  is hidden by the parent link.

- New owner dry-run command:

  ```bash
  DOT_PROFILE=work mise bootstrap dotfiles apply --dry-run
  ```

- New owner apply command:

  ```bash
  DOT_PROFILE=work mise bootstrap dotfiles apply --yes
  ```

- Duplicate-owner check: run `stow -nvR .` and verify that its output contains
  no `LINK`, `UNLINK`, or conflict entry for `.config/mise`; verify that the
  target is a physical directory and that its managed children are links to
  `~/dev/personal/dot/home/.config/mise`, not to `.config/mise`.
- Target-content disposition check: run `mise bootstrap dotfiles status`, then
  compare the 19 expected relative paths from the scope manifest with
  `find "$HOME/.config/mise" -type l -print | sort`. No regular managed file
  or unexpected local file may be replaced.
- Relative-link check: require `test ! -L "$HOME/.config/mise"` and require
  every managed child link target from `readlink` to be relative. Confirm
  `relative_symlinks = true` remains in `~/dev/personal/dot/home/.config/mise/config.toml`.

The new declaration must account for its final location. Declarations loaded
from `~/.config/mise/conf.d` must use explicit source paths rooted at
`~/dev/personal/dot/home/...`. Do not set `dotfiles.root` for this migration.
Do not assume that the old relative path remains valid. The requested
declaration path must also avoid recursively claiming the target directory that
contains the declaration itself. Stop on any dry-run that proposes an
unrelated target or leaves a parent-directory link in place.

## Coupling

- Scripts:
  - `scripts/mise.zsh` exports `MISE_ENV`, applies packages, files, tools,
    repositories, and dotfiles in that order, and already applies dotfiles as
    the final phase. No new initialization phase is required.
  - `scripts/init.zsh` persists the selected profile, then sources both the
    Stow and mise phases. Preserve the existing phase order.
  - `scripts/symlink.zsh` runs `stow -vR .`; the old `.config/mise` source must
    be removed or narrowly excluded before the selected transition mechanism
    can stop owning the target.
  - `tests/scripts/test_mise_config.zsh` currently asserts `.config/mise`
    source paths, profile loading, task discovery, initialization order,
    global Git ignore installation, and Stow ignores. Its path assertions must
    follow the new source location during implementation.
- Environment variables:
  - `DOT_PROFILE` selects `work` or `personal` and is rendered by
    `miserc.toml`.
  - `MISE_ENV` currently overrides the `miserc.toml` selection and is exported
    from `scripts/mise.zsh`; replace that export with `unset MISE_ENV` after
    profile validation.
  - `XDG_CONFIG_HOME` is used by mise and the focused test to isolate the
    global configuration.
  - `GH_CONFIG_DIR` is rendered by `~/dev/personal/dot/home/dev/profile.mise.toml` for generated
    workspace configs; it is coupled to `bootstrap-gh.toml`, not a new secret
    source.
- Includes or external paths:
  - `miserc.toml` enables `conf.d` loading.
  - `bootstrap-gh.toml` consumes `~/dev/personal/dot/home/dev/profile.mise.toml` and renders two
    workspace configs.
  - `tasks/git/worktree.ts` and `tasks/pr/sync.ts` import
    `../../utils/git.js`; preserve the relative task tree.
  - `tasks/md/preview.ts` writes ignored project state to
    `tmp/md-preview/instances.json`; keep it outside tracked sources.
  - `config.toml` names `.env` as an environment file; no boundary-local file
    exists, and no external environment file may be copied.
- Other modules:
  - `bootstrap-ai`, `bootstrap-gh`, `bootstrap-packages`,
    `bootstrap-packages.personal`, `bootstrap-repos`, and `tools` are the
    existing `conf.d` declarations that consume this control plane.
  - The project-only `.mise` configuration remains separate and must not be moved
    into `~/.config/mise`.
- User-facing behavior:
  - Preserve global mise settings, task discovery, profile selection, package
    and repository bootstrap, tool postinstall tasks, and generated workspace
    profile files.
  - This module owns only the global control-plane files and
    `module.mise.toml`. Later module stories own their declarations.
  - Render `env = ["work", "mise"]` for the work profile and
    `env = ["personal", "mise"]` for the personal profile. Add later module
    environments only when their declarations migrate.
  - Keep unscoped legacy fragments as the transition bridge until their module
    stories rename them.
  - Replace only the Stow parent symlink with mise-managed per-file links.
    Keep project `.mise` state and tool-owned runtime state separate.

## Validation

- Syntax or source checks:
  - `for path in .config/mise/tasks/*.sh .config/mise/tasks/*.zsh; do zsh -n "$path"; done`
    for shell task syntax; the current shell task set passes this check.
  - Verify all 19 expected source paths, tracked modes, and SHA-256 manifests
    before and after the copy. The current source modes are 0644 for
    declarations, config, lockfile, miserc, and utility files, and 0755 for
    task files.
  - Parse the relocated TOML through mise during the target-scoped dry run.
- Focused test:
  - `tests/scripts/test_mise_config.zsh`
  - This module test owns global mise configuration and initialization wiring.
    It must render isolated work and personal profile fixtures, assert the
    `mise` module selection, preserve the legacy personal package selection,
    and run with `MISE_ENV` unset.
- Target smoke test:
  - `env -u MISE_ENV DOT_PROFILE=work mise tasks ls`
  - `env -u MISE_ENV DOT_PROFILE=work mise bootstrap dotfiles status`
  - `env -u MISE_ENV DOT_PROFILE=work mise config ls`
  - `env -u MISE_ENV DOT_PROFILE=personal mise config ls`
  - `mise run lint-skill-index`
  - `mise run lint-skill-index --base-path home`
  - Confirm `git:worktree`, `md:preview`, `pr:sync`, package-install tasks,
    `bootstrap`, and `lint-skill-index` remain discoverable after linking.
- Security or token check:
  - Use names-only scans so credential-bearing contents are not printed:
    `git grep -Il -E '(token|password|secret|credential|private[_-]?key|api[_-]?key|access[_-]?key)' -- ~/dev/personal/dot/home/.config/mise`
  - Check that no `.db`, `.wal`, history, authentication, token, secret, or
    local-variant file is present in the new source.
  - Preserve the existing token-free GitHub hosts invariant and keep
    tool-owned runtime data outside both source trees.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

The current `stow -nvR .` baseline reports the existing whole-directory
`.config/mise` link as a Stow action. This is evidence for the ownership
transition, not a reason to adopt runtime files.

## Rollback

- Preserve before cutover:
  - The complete `.config/mise` source tree, its tracked modes, and its
    SHA-256 manifest.
  - The exact current target link text:
    `../dev/personal/dot/.config/mise`.
  - Both lockfiles, the `.mise` project bridge, generated workspace profile
    files, the persisted profile selector, and ignored `tmp/md-preview` state.
  - The pre-transition output of `stow -nvR .`, `mise bootstrap dotfiles
status`, and `mise bootstrap dotfiles apply --dry-run`.
- Rollback dry run:

  ```bash
  mise bootstrap dotfiles unapply --dry-run
  stow -nvR .
  ```

  Proceed only if the unapply output names the intended
  `~/.config/mise/**` links and the Stow dry run proposes the original
  `.config/mise` parent link without unrelated targets.

- Rollback apply:

  ```bash
  mise bootstrap dotfiles unapply --yes
  test ! -e "$HOME/.config/mise" && test ! -L "$HOME/.config/mise"
  ln -s ../dev/personal/dot/.config/mise "$HOME/.config/mise"
  ```

  Restore the original source and declaration files from the preserved
  manifest before re-running the Stow dry run. Do not use `stow --adopt`.

- Stop condition:
  - Any unapply dry run names targets outside `~/.config/mise/**`.
  - A local variant, regular file, absolute link, credential-bearing file, or
    tool-owned runtime file would be removed or overwritten.
  - The mise dry run cannot resolve the new explicit source path.
  - Stow still proposes two owners for `~/.config/mise`.

## Findings and decisions

- Decision: `resolved`
- Resolved decision: `DEC-mise-control-plane-transition-mechanism`
- Resolved decision: `DEC-mise-control-plane-source-resolution`
- Decision evidence:
  - The initial `git ls-files -- .config/mise` baseline listed 19 tracked
    candidates. The empty aggregate declaration was retired, leaving 18 active
    source files, and the ignored-inclusive manifest remains empty.
  - `readlink "$HOME/.config/mise"` returns the current relative Stow link
    `../dev/personal/dot/.config/mise`.
  - `mise bootstrap dotfiles status` and its dry run show the existing mise
    control plane is active for other boundaries.
  - `.config/mise/config.toml` already sets
    `settings.dotfiles.relative_symlinks = true`.
  - `.config/mise/miserc.toml`, `scripts/init.zsh`, `scripts/mise.zsh`, the
    project `.mise` bridge, and the focused tests establish profile, task,
    lockfile, and initialization coupling.
  - The source and target scans found no local variants or credential-named
    files. Runtime state is confined to ignored project state and external
    profile state.
  - mise accepts explicit `~/dev/personal/dot/home/...` source paths when the
    declaration is loaded from `~/.config/mise/conf.d`.
- Residual risk:
  - The requested declaration path is below the new source tree, so its
    explicit source paths and self-inclusion behavior require a target-scoped
    dry run.
  - Existing tests and README paths describe `.config/mise` and need approved
    implementation updates.
  - An inherited `MISE_ENV` takes precedence over `miserc.toml`; the focused
    test and `scripts/mise.zsh` change must prevent stale profile selection.
  - The cutover retains the temporary bridge. Do not replace it with a
    generated shell script.
- Open blocker:
  - None. The roadmap and registry mark this story `done`, and its approval
    record is `approved`.
