# Module Inventory: `copilot`

## Metadata

- Module key: `copilot`
- Story key: `MIG-MODULE-copilot`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/copilot.md`
- Current declaration: `.config/mise/conf.d/bootstrap-ai.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.copilot.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~/.copilot`
- Mise mode: per-target `symlink` entries
- Environment selector: `copilot`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                                | Tracked | Ignored | Current owner | Current target                       | Target disposition | New source path                                          | New target                           | New mode  | Notes                                                                                                                                 |
| ---------------------------------------------------------- | ------- | ------- | ------------- | ------------------------------------ | ------------------ | -------------------------------------------------------- | ------------------------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `~/dev/personal/dot/home/.copilot/copilot-instructions.md` | `yes`   | `no`    | `mise`        | `~/.copilot/copilot-instructions.md` | `migrate`          | `~/dev/personal/dot/home/AGENTS.md`                      | `~/.copilot/copilot-instructions.md` | `symlink` | Current source is a tracked alias to `~/dev/personal/dot/home/AGENTS.md`; deploy the target directly from the shared `agents` source. |
| `~/dev/personal/dot/home/.copilot/statusline-context.sh`   | `yes`   | `no`    | `mise`        | `~/.copilot/statusline-context.sh`   | `migrate`          | `~/dev/personal/dot/home/.copilot/statusline-context.sh` | `~/.copilot/statusline-context.sh`   | `symlink` | Tracked executable source; preserve executable mode and the current statusline behavior.                                              |

## Local and runtime inventory

| Path                                                       | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                 | Classification    | Required action | Runtime destination | Metadata to preserve                                    | Secret or sensitive data |
| ---------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----------------- | --------------- | ------------------- | ------------------------------------------------------- | ------------------------ |
| `~/dev/personal/dot/home/.copilot/copilot-instructions.md` | `yes`  | `no`    | `no`    | `repo`           | Tracked symlink to `~/dev/personal/dot/home/AGENTS.md`; the new module uses `~/dev/personal/dot/home/AGENTS.md` directly.           | `repository-only` | `preserve`      | `none`              | Relative symlink target `../AGENTS.md`; `villalj:staff` | `no`                     |
| `~/.copilot/` unmanaged runtime                            | `yes`  | `no`    | `no`    | `target`         | Running `copilot` process had open handles under `~/.copilot/` for session database, WAL, session state, and logs; no contents read | `mixed`           | `preserve`      | `~/.copilot/`       | Directory `0700`; application-owned runtime files       | `yes`                    |

The repository source boundary contains only the two managed `~/dev/personal/dot/home/.copilot`
files and the repository-only instructions alias.

For the source boundary, `git ls-files -- ~/dev/personal/dot/home/.copilot` returns the two
tracked files above. The new module manages `~/dev/personal/dot/home/AGENTS.md` and
`~/dev/personal/dot/home/.copilot/statusline-context.sh`; the Copilot instructions alias remains
repository-only. Both
`git ls-files --others --ignored --exclude-standard -- ~/dev/personal/dot/home/.copilot` and
`git ls-files --others --exclude-standard -- ~/dev/personal/dot/home/.copilot` return no paths.

The current `~/.copilot/` target is also mixed by design: the two managed
files are relative symlinks into `~/dev/personal/dot/home/.copilot`, and the target retains
application-owned runtime entries. The new module must link the instructions
target directly to `~/dev/personal/dot/home/AGENTS.md` and leave the tracked alias repository-only.
A running Copilot process opened only `~/.copilot/` runtime paths during
inspection. Do not inspect or print unmanaged runtime database, WAL, token, or
credential contents.

## Ownership and cutover

- Current target shape: `per-file links plus unmanaged physical runtime files`
- Current target manifest path: `~/.copilot`
- Old owner cleanup command: `mise dot unapply --dry-run ~/.copilot`, then `mise dot unapply ~/.copilot` only after the new module is ready
- New owner dry-run command: `mise bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise bootstrap dotfiles apply`
- Duplicate-owner check: `stow -nvR .` and `mise bootstrap dotfiles status | grep -F '~/.copilot'`
- Target-content disposition check: `find -P ~/.copilot -maxdepth 1 -mindepth 1 -type l -print -exec readlink -- {} \;` followed by `find -P ~/.copilot -maxdepth 1 -mindepth 1 ! -type l -print`
- Relative-link check: `find ~/.copilot -maxdepth 1 -type l -exec readlink -- {} \; | grep -E '^/'` must return no lines

## Coupling

- Scripts:
  - Create `~/dev/personal/dot/home/.config/mise/conf.d/module.copilot.toml` with:

    ```toml
    [dotfiles]
    "~/.copilot/copilot-instructions.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }
    "~/.copilot/statusline-context.sh" = { source = "~/dev/personal/dot/home/.copilot/statusline-context.sh", mode = "symlink" }
    ```

  - Remove the `~/.copilot` entry from `.config/mise/conf.d/bootstrap-ai.toml` only after the new module is selected and the target links pass validation.
  - Update the AI bootstrap test to assert the new module path and source string.

  - Keep the repository-only instructions alias outside the module source set.
- Environment variables:
  - `HOME` expands the `~/.copilot` target. No Copilot-specific environment variable was observed in the running process.
- Includes or external paths:
  - `~/dev/personal/dot/home/.copilot/copilot-instructions.md` remains a tracked repository-only symlink to `~/dev/personal/dot/home/AGENTS.md`.
  - The target declaration uses `~/dev/personal/dot/home/AGENTS.md` directly, so the shared `agents` source must remain available.
- Other modules:
  - `agents` supplies the shared instructions source.
- User-facing behavior:
  - Keep `~/.copilot/copilot-instructions.md` and `~/.copilot/statusline-context.sh` linked per file.
  - Link `~/.copilot/copilot-instructions.md` directly to `~/dev/personal/dot/home/AGENTS.md`.
  - Preserve all application-owned `~/.copilot` runtime files.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch -- ~/dev/personal/dot/home/AGENTS.md ~/dev/personal/dot/home/.copilot/copilot-instructions.md ~/dev/personal/dot/home/.copilot/statusline-context.sh`
  - `zsh -n ~/dev/personal/dot/home/.copilot/statusline-context.sh`
  - `test "$(readlink ~/dev/personal/dot/home/.copilot/copilot-instructions.md)" = "../AGENTS.md"`
  - Make sure that `module.copilot.toml` maps the instructions target to
    `~/dev/personal/dot/home/AGENTS.md`.
- Focused test:
  - `tests/scripts/test_mise_bootstrap_copilot.zsh`
- Target smoke test:
  - `test -L ~/.copilot/copilot-instructions.md && test -L ~/.copilot/statusline-context.sh && test -x ~/.copilot/statusline-context.sh`
  - Make sure that `~/.copilot/copilot-instructions.md` resolves to
    `~/dev/personal/dot/home/AGENTS.md`, not to `~/dev/personal/dot/home/.copilot/copilot-instructions.md`.
- Security or token check:
  - `find ~/dev/personal/dot/home/.copilot -type f -print`
  - Do not read or print unmanaged runtime, token, or credential contents.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - The current `.config/mise/conf.d/bootstrap-ai.toml` entry, `~/dev/personal/dot/home/AGENTS.md`, the repository-only Copilot alias, and the statusline source.
  - The current `~/.copilot` managed links and every unmanaged runtime entry.
- Rollback dry run:
  - Restore the aggregate declaration, then run `mise bootstrap dotfiles apply --dry-run` and `mise dot unapply --dry-run ~/.copilot` only if the dry run names the intended managed links.
- Rollback apply:
  - Restore the aggregate declaration and run `mise bootstrap dotfiles apply`.
- Stop condition:
  - Stop if a dry run proposes deleting an unmanaged `~/.copilot` runtime file, replacing a physical target directory, creating an absolute link, or leaving both aggregate and module declarations active.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `mise bootstrap dotfiles status` reports `~/.copilot` applied from the current aggregate declaration with `symlink-each`.
  - `~/.copilot` contains relative links for the two tracked sources and separate application-owned runtime files.
  - The new target entry uses `~/dev/personal/dot/home/AGENTS.md` instead of the tracked Copilot alias.
  - The deleted repository-side runtime boundary no longer appears in the Stow dry run.
- Residual risk:
  - The unmanaged target state contains sensitive application data and must
    remain application-owned.
  - The aggregate-to-module cutover must preserve the `agents` source dependency and avoid duplicate mise declarations.
- Open blocker:
  - None. The roadmap and registry mark this story `done`, and its approval
    record is `approved`.
