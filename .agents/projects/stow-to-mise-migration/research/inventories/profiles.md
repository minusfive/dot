# Module Inventory: `profiles`

## Metadata

- Module key: `profiles`
- Story key: `MIG-MODULE-profiles`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/profiles.md`
- Current declaration: `.config/mise/conf.d/bootstrap-gh.toml`
- New declaration: `home/.config/mise/conf.d/module.profiles.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~/dev`
- Mise mode: `template`
- Environment selector: `profiles`
- Dependencies: `MIG-MODULE-gh`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                  | Tracked | Ignored | Current owner | Current target             | Target disposition | New source path              | New target                 | New mode   | Notes                                                              |
| ---------------------------- | ------- | ------- | ------------- | -------------------------- | ------------------ | ---------------------------- | -------------------------- | ---------- | ------------------------------------------------------------------ |
| `home/dev/profile.mise.toml` | `yes`   | `no`    | `mise`        | `~/dev/personal/mise.toml` | `migrate`          | `home/dev/profile.mise.toml` | `~/dev/personal/mise.toml` | `template` | Render target-specific `GH_CONFIG_DIR` for the personal workspace. |
| `home/dev/profile.mise.toml` | `yes`   | `no`    | `mise`        | `~/dev/work/mise.toml`     | `migrate`          | `home/dev/profile.mise.toml` | `~/dev/work/mise.toml`     | `template` | Render target-specific `GH_CONFIG_DIR` for the work workspace.     |

## Local and runtime inventory

| Path                                    | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                       | Classification  | Required action   | Runtime destination                | Metadata to preserve                  | Secret or sensitive data |
| --------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------- | ----------------- | ---------------------------------- | ------------------------------------- | ------------------------ |
| `home/dev/profile.mise.toml`            | `yes`  | `yes`   | `no`    | `repo`           | `bootstrap-gh.toml` references it for both workspace targets.                                                             | `active-global` | `preserve`        | `none`                             | `0644, repository source, user-owned` | `no`                     |
| `.config/mise/conf.d/bootstrap-gh.toml` | `yes`  | `yes`   | `no`    | `repo`           | Loaded as a `conf.d` fragment; it contains the two profile `[bootstrap.files]` entries plus GitHub resources.             | `mixed`         | `preserve`        | `none`                             | `0644, repository source, user-owned` | `no`                     |
| `~/dev/personal/mise.toml`              | `yes`  | `no`    | `no`    | `target`         | Current rendered file sets `GH_CONFIG_DIR` to the personal GitHub config directory; `mise config` lists it.               | `active-global` | `copy-then-erase` | `~/dev/personal/mise.toml`         | `0644, user-owned, staff group`       | `no`                     |
| `~/dev/work/mise.toml`                  | `yes`  | `no`    | `no`    | `target`         | Current rendered file sets `GH_CONFIG_DIR` to the work GitHub config directory; `mise config` lists it.                   | `active-global` | `copy-then-erase` | `~/dev/work/mise.toml`             | `0644, user-owned, staff group`       | `no`                     |
| `~/.local/state/minusfive/profile`      | `yes`  | `no`    | `no`    | `other`          | `scripts/functions.zsh` reads and writes this selector; `scripts/init.zsh` persists it before loading `scripts/mise.zsh`. | `active-global` | `preserve`        | `~/.local/state/minusfive/profile` | `0644, user-owned, staff group`       | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

No ignored or non-ignored untracked files were found for
`home/dev/profile.mise.toml` or `.config/mise/conf.d/bootstrap-gh.toml`.
The two workspace targets are outside the repository and are not Git-managed.
No credential-bearing contents were copied into this inventory.

## Ownership and cutover

- Current target shape: `physical files`
- Current target manifest path: `none; the targets are regular files rendered by the current bootstrap declaration`
- Old owner cleanup command: `mise bootstrap unapply profiles --dry-run`, then `mise bootstrap unapply profiles --yes` after the staged old `[bootstrap.files]` entries load under the `profiles` environment and the dry run names only the two workspace targets.
- New owner dry-run command: `mise -E profiles bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E profiles bootstrap dotfiles apply --yes`
- Duplicate-owner check: `! rg -n '^\[bootstrap\.files\."~/dev/(personal|work)/mise\.toml"\]' .config/mise/conf.d home/.config/mise/conf.d && stow -nvR . 2>&1 | ! rg -n 'dev/(personal|work)/mise\.toml' && rg -n '^"~/dev/(personal|work)/mise\.toml"[[:space:]]*=' home/.config/mise/conf.d/module.profiles.toml`
- Target-content disposition check: `grep -Fxq 'GH_CONFIG_DIR = "{{ env.HOME }}/.config/gh/{{ target | dirname | basename }}"' home/dev/profile.mise.toml && grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/personal\"" "$HOME/dev/personal/mise.toml" && grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/work\"" "$HOME/dev/work/mise.toml"`
- Relative-link check: `for target in "$HOME/dev/personal/mise.toml" "$HOME/dev/work/mise.toml"; do test -f "$target" && test ! -L "$target"; done`

## Coupling

- Scripts:
  - `.config/mise/conf.d/bootstrap-gh.toml`: split the two workspace `[bootstrap.files]` entries into `module.profiles.toml`; keep the GitHub directory and host resources for `MIG-MODULE-gh` until that module's transition completes.
  - `scripts/mise.zsh`: currently runs `mise bootstrap files apply --yes` and trusts both workspace files at lines 76-78, before the `mise bootstrap dotfiles apply --yes` phase at line 114. Keep directory bootstrap in the files phase, then apply the profile templates and trust both targets after the dotfiles phase.
  - `scripts/init.zsh` and `scripts/functions.zsh`: read and persist the selected profile at `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` before the mise phase runs.
- Environment variables:
  - `GH_CONFIG_DIR`: `home/dev/profile.mise.toml` derives `{{ env.HOME }}/.config/gh/{{ target | dirname | basename }}`; current targets render the `personal` and `work` directories.
  - `DOT_PROFILE`: selected by `scripts/init.zsh`, persisted outside the repository, and used by the mise `miserc.toml` template to select modules.
  - `MISE_ENV`: currently exported from `scripts/mise.zsh` from the selected profile; the migration roadmap requires keeping `DOT_PROFILE` as the profile input and removing this legacy export when module selection is wired.
- Includes or external paths:
  - `.config/mise/miserc.toml` currently bridges `DOT_PROFILE` to the selected mise environment; the migrated control-plane source must retain that bridge.
- Other modules:
  - `MIG-MODULE-gh` owns the shared GitHub directory and token-free hosts file from the same old declaration and must be migrated before this module.
- User-facing behavior:
  - Preserve both workspace target paths, file mode `0644`, target-specific `GH_CONFIG_DIR` values, profile persistence, and trust of both rendered workspace files. Change only the resource owner from `[bootstrap.files]` to template `[dotfiles]` entries.
  - This module is the only migration module that writes the two workspace profile targets.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch home/dev/profile.mise.toml && mise -E profiles config ls`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_profiles.zsh` (planned module test; split profile assertions from the legacy GitHub coverage).
- Target smoke test:
  - `mise -E profiles bootstrap dotfiles apply --dry-run`, followed by the target-content disposition check above.
- Security or token check:
  - `! rg -n -i '(oauth_token|token[[:space:]]*=|password[[:space:]]*=|secret[[:space:]]*=|private_key)' home/dev/profile.mise.toml`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-gh.toml`, `home/dev/profile.mise.toml`, both rendered workspace targets, the persisted profile state, and the pre-transition dry-run output.
- Rollback dry run:
  - `mise bootstrap unapply profiles --dry-run`
- Rollback apply:
  - `mise bootstrap unapply profiles --yes`, restore the profile `[bootstrap.files]` entries in `.config/mise/conf.d/bootstrap-gh.toml`, then run `mise bootstrap files apply --yes`.
- Stop condition:
  - Stop if any dry run names a target other than the two workspace files, removes the GitHub directory or hosts resource, proposes a Stow target, or changes content beyond the target-specific `GH_CONFIG_DIR`.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-gh.toml` contains both workspace targets as `[bootstrap.files]` with the shared source.
  - `home/dev/profile.mise.toml` contains the target-derived `GH_CONFIG_DIR` template.
  - The current workspace targets are regular `0644` files with distinct rendered personal and work GitHub config paths.
  - `scripts/mise.zsh` trusts the workspace files before applying mise dotfiles; profile persistence occurs earlier in `scripts/init.zsh`.
  - `MIG-MODULE-gh` is the recorded dependency in `module-registry.toml`.
- Residual risk:
  - The old declaration is an unscoped `conf.d` fragment, so the cleanup must stage or otherwise select the `profiles` environment before `mise bootstrap unapply profiles --dry-run`; proceed only when that dry run names exactly the two profile targets. The existing GitHub focused test also encodes the old aggregate declaration.
- Open blocker:
  - The current unscoped `bootstrap-gh.toml` fragment has no direct targeted unapply selector. Execution must stage the profile entries under `profiles` or produce an equivalent target-scoped dry run before cleanup; migration approval remains pending.
