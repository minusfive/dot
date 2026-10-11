# Module Inventory: `claude`

## Metadata

- Module key: `claude`
- Story key: `MIG-MODULE-claude`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/claude.md`
- Current declaration: `.config/mise/conf.d/bootstrap-ai.toml`
- New declaration: `home/.config/mise/conf.d/module.claude.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~/.claude`
- Mise mode: explicit `symlink` and `symlink-each` entries
- Environment selector: `claude`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                             | Tracked | Ignored | Current owner | Current target                    | Target disposition | New source path                               | New target                        | New mode       | Notes                                                                                                                  |
| --------------------------------------- | ------- | ------- | ------------- | --------------------------------- | ------------------ | --------------------------------------------- | --------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/bootstrap-ai.toml` | `yes`   | `no`    | `mise`        | `none`                            | `migrate`          | `home/.config/mise/conf.d/module.claude.toml` | `none`                            | `symlink-each` | Split the Claude entry from the aggregate AI declaration; retain the current source boundary and target.               |
| `home/.claude/settings.json`            | `yes`   | `no`    | `mise`        | `~/.claude/settings.json`         | `migrate`          | `home/.claude/settings.json`                  | `~/.claude/settings.json`         | `symlink`      | Tracked settings source. Preserve the statusline reference without printing settings values.                           |
| `home/.claude/skills`                   | `yes`   | `no`    | `mise`        | `~/.claude/skills`                | `migrate`          | `home/.agents/skills`                         | `~/.claude/skills`                | `symlink-each` | Current source is a tracked cross-boundary alias; use the agents source directly and exclude `**/evals/**/outputs/**`. |
| `home/.claude/statusline-command.sh`    | `yes`   | `no`    | `mise`        | `~/.claude/statusline-command.sh` | `migrate`          | `home/.claude/statusline-command.sh`          | `~/.claude/statusline-command.sh` | `symlink`      | Tracked executable statusline source; preserve executable mode and runtime path references.                            |

## Local and runtime inventory

| Path                                                                                                                                                                                                                                                                                             | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                           | Classification     | Required action | Runtime destination                   | Metadata to preserve                                                                                       | Secret or sensitive data |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------- | ------------------ | --------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.config/mise/conf.d/bootstrap-ai.toml`                                                                                                                                                                                                                                                          | `yes`  | `yes`   | `no`    | `repo`           | Current `[dotfiles]` entry deploys `~/.claude`; the module-focused test will check the split declaration.     | `active-global`    | `move`          | `none`                                | TOML declaration, source path, target path, and `symlink-each` mode                                        | `no`                     |
| `home/.claude/settings.json`                                                                                                                                                                                                                                                                     | `yes`  | `yes`   | `no`    | `repo`           | The current target is a relative symlink; the focused AI test checks the source and the statusline reference. | `active-global`    | `preserve`      | `~/.claude/settings.json`             | Tracked JSON file mode `0644`; preserve settings structure without copying values into research artifacts. | `unknown`                |
| `home/.claude/skills`                                                                                                                                                                                                                                                                            | `yes`  | `yes`   | `no`    | `repo`           | Tracked symlink to `home/.agents/skills`; the new module uses the agents source directly.                     | `repository-only`  | `preserve`      | `none`                                | Relative symlink target `../.agents/skills`; preserve the alias without deploying it.                      | `no`                     |
| `home/.claude/statusline-command.sh`                                                                                                                                                                                                                                                             | `yes`  | `yes`   | `no`    | `repo`           | The settings source references this command; the target is an active relative symlink.                        | `active-global`    | `preserve`      | `~/.claude/statusline-command.sh`     | Tracked executable file mode `0755`; preserve shell syntax and executable permissions.                     | `no`                     |
| `.claude/settings.local.json`                                                                                                                                                                                                                                                                    | `yes`  | `no`    | `yes`   | `repo`           | `~/.claude/settings.local.json` is a symlink to this file; the global Git excludes file ignores it.           | `active-repo-only` | `preserve`      | `~/.claude/settings.local.json`       | Local JSON file mode `0644`; preserve the target symlink and keep the file outside `home/.claude`.         | `unknown`                |
| `~/.claude/backups`, `~/.claude/cache`, `~/.claude/debug`, `~/.claude/file-history`, `~/.claude/paste-cache`, `~/.claude/plans`, `~/.claude/plugins`, `~/.claude/projects`, `~/.claude/session-env`, `~/.claude/sessions`, `~/.claude/shell-snapshots`, `~/.claude/tasks`, `~/.claude/telemetry` | `yes`  | `no`    | `no`    | `target`         | Existing Claude-managed directories coexist with the deployed links under the physical target root.           | `active-global`    | `preserve`      | same target paths                     | Tool-owned directories; preserve contents, ownership, permissions, and local application state.            | `yes`                    |
| `~/.claude/history.jsonl`                                                                                                                                                                                                                                                                        | `yes`  | `no`    | `no`    | `target`         | Existing Claude history file under the target root.                                                           | `active-global`    | `preserve`      | `~/.claude/history.jsonl`             | Tool-owned file mode `0600`; preserve contents and permissions without reading it.                         | `yes`                    |
| `~/.claude/mcp-needs-auth-cache.json`                                                                                                                                                                                                                                                            | `yes`  | `no`    | `no`    | `target`         | Existing Claude authentication cache under the target root.                                                   | `active-global`    | `preserve`      | `~/.claude/mcp-needs-auth-cache.json` | Tool-owned cache metadata and permissions; do not copy or print contents.                                  | `yes`                    |
| `~/.claude/monthly-usage.json`, `~/.claude/monthly-usage.json.Vlg1Jd`, `~/.claude/monthly-usage.json.lock`                                                                                                                                                                                       | `yes`  | `no`    | `no`    | `target`         | `statusline-command.sh` reads and updates the monthly usage file and uses its lock path.                      | `active-global`    | `preserve`      | same target paths                     | Tool-owned usage state, stale temporary state, and lock directory; preserve names and permissions.         | `no`                     |
| `~/.claude/.last-cleanup`, `~/.claude/stats-cache.json`                                                                                                                                                                                                                                          | `yes`  | `no`    | `no`    | `target`         | Existing cleanup marker and statistics cache coexist with the managed links.                                  | `active-global`    | `preserve`      | same target paths                     | Preserve tool-owned marker and cache metadata; do not declare these paths in mise.                         | `unknown`                |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- home/.claude
git check-ignore -v <path>
```

The `home/.claude` boundary has no untracked or ignored source entries. The
tracked `home/.claude/skills` alias remains repository-only. The target runtime
entries are outside the repository, so their Git `Ignored` value is `no` and
their exclusion is by ownership, not by a repository ignore rule. The one
ignored local settings source is `.claude/settings.local.json`, reported by
`git check-ignore -v` through the global Git excludes file. Do not print
settings, history, cache, authentication, or usage contents.

## Ownership and cutover

- Current target shape: `physical directory with per-file relative symlinks and tool-owned runtime entries`
- Current target manifest path: `~/.claude`
- Old owner cleanup command: `mise -C . dot unapply --dry-run ~/.claude`
- New owner dry-run command: `mise -C . dot apply --dry-run ~/.claude`
- New owner apply command: `mise -C . dot apply ~/.claude`
- Duplicate-owner check: `grep -R -nE '"~/.claude"|(^|/)\.claude(/|$)' .config/mise home/.config/mise .config .stow-local-ignore 2>/dev/null`
- Target-content disposition check: `mise -C . dot status ~/.claude` and a target-root listing that confirms runtime paths remain outside `home/.claude`
- Relative-link check: `for path in "$HOME/.claude/settings.json" "$HOME/.claude/statusline-command.sh"; do link=$(readlink "$path") && test -L "$path" && test "${link#/}" = "$link" || exit 1; done; find "$HOME/.claude/skills" -type l -exec sh -c 'case "$(readlink "$1")" in /*) exit 1;; esac' _ {} \;`

## Coupling

- Scripts:
  - `scripts/mise.zsh` already applies the mise dotfiles phase; no new initialization phase is required for the split module.
  - Create `home/.config/mise/conf.d/module.claude.toml` with:

    ```toml
    [dotfiles]
    "~/.claude/settings.json" = { source = "../../../.claude/settings.json", mode = "symlink" }
    "~/.claude/skills" = { source = "../../../.agents/skills", mode = "symlink-each", exclude = ["**/evals/**/outputs/**"] }
    "~/.claude/statusline-command.sh" = { source = "../../../.claude/statusline-command.sh", mode = "symlink" }
    ```

  - Split the current aggregate AI assertions into the Claude module-focused
    test during execution.
- Environment variables:
  - `HOME` determines the `~/.claude` target and the statusline runtime state path; the statusline command consumes Claude JSON on standard input.
- Includes or external paths:
  - `home/.claude/skills` remains a tracked repository-only alias to `home/.agents/skills`.
  - The new target source is `home/.agents/skills` and excludes `**/evals/**/outputs/**`.
  - `home/.claude/statusline-command.sh` uses external commands including `jq`, `git`, `awk`, `stat`, `date`, and `mktemp`, and writes only tool-owned runtime state below `~/.claude`.
  - `~/.claude/settings.local.json` points to the ignored repository-local `.claude/settings.local.json`; it is not part of the migrated source boundary.
- Other modules:
  - `MIG-MODULE-mise` must provide the mise control plane before this module is selected.
  - `MIG-MODULE-agents` is a soft runtime coupling because the tracked `skills` symlink resolves into the agents source boundary.
- User-facing behavior:
  - Preserve Claude settings, skills, and the executable statusline command.
  - Link managed skills directly from `home/.agents/skills`.
  - Keep generated evaluation output outside `~/.claude/skills`.
  - Preserve all existing Claude runtime data in the physical target directory.
  - Do not migrate histories, caches, authentication caches, usage state, local settings, or other tool-owned runtime paths.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch home/.claude/settings.json home/.claude/skills home/.claude/statusline-command.sh`
  - `bash -n home/.claude/statusline-command.sh`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/claude.md`
  - Make sure that `module.claude.toml` maps `~/.claude/skills` to `../../../.agents/skills` with the output exclusion.
- Focused test:
  - `tests/scripts/test_mise_bootstrap_claude.zsh`
- Target smoke test:
  - `mise -C . dot status ~/.claude`
  - Verify that the settings and statusline targets are relative symlinks, the skills directory contains relative links, and the existing runtime paths remain present and unmanaged.
  - Make sure that no generated evaluation output is linked below `~/.claude/skills`.
- Security or token check:
  - `! git grep -IlE 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- home/.claude`
  - `git check-ignore -v .claude/settings.local.json`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-ai.toml`, the proposed module declaration, the direct `home/.agents/skills` source, the repository-only Claude alias, and the two Claude files.
  - The current target links and every existing runtime path below `~/.claude`, including the ignored `.claude/settings.local.json` link.
- Rollback dry run:
  - Restore the aggregate AI declaration and remove the selected Claude module, then run `mise -C . dot apply --dry-run ~/.claude`.
- Rollback apply:
  - Restore `.config/mise/conf.d/bootstrap-ai.toml`, remove the module-specific declaration, and run `mise -C . dot apply ~/.claude`; restore any detached runtime path before applying.
- Stop condition:
  - Stop if a dry run proposes a runtime path, the ignored local settings link, generated evaluation output, an unexpected source or target, a non-relative link, content replacement, or simultaneous aggregate and module ownership.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-ai.toml` declares the current Claude target with `symlink-each`.
  - `home/.claude/settings.json`, the repository-only `home/.claude/skills` alias, and `home/.claude/statusline-command.sh` are the tracked Claude entries.
  - The new skills target uses `home/.agents/skills` directly and excludes generated evaluation output.
- Residual risk:
  - The settings file may contain machine-local paths or behavior that must remain unprinted; the statusline command writes usage state below the target; and the direct skills source depends on the agents source boundary.
- Open blocker:
  - `none for inventory; migration execution remains pending explicit approval, module split, and focused module-test coverage`
