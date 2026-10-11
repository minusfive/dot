# Module Inventory: `opencode`

## Metadata

- Module key: `opencode`
- Story key: `MIG-MODULE-opencode`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/opencode.md`
- Current declaration: `.config/mise/conf.d/bootstrap-ai.toml`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.opencode.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~/.config/opencode`
- Mise mode: `symlink-each`
- Environment selector: `opencode`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                                         | Tracked | Ignored | Current owner | Current target                                | Target disposition | New source path                                                     | New target                                    | New mode       | Notes                                                                                                                   |
| ------------------------------------------------------------------- | ------- | ------- | ------------- | --------------------------------------------- | ------------------ | ------------------------------------------------------------------- | --------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/bootstrap-ai.toml:7`                           | `yes`   | `no`    | `mise`        | `~/.config/opencode`                          | `migrate`          | `~/dev/personal/dot/home/.config/mise/conf.d/module.opencode.toml`  | `~/.config/opencode`                          | `symlink-each` | Split only the OpenCode dotfile entry; retain the other AI entries until their module cutovers.                         |
| `~/dev/personal/dot/home/.config/opencode/opencode.jsonc`           | `yes`   | `no`    | `mise`        | `~/.config/opencode/opencode.jsonc`           | `migrate`          | `~/dev/personal/dot/home/.config/opencode/opencode.jsonc`           | `~/.config/opencode/opencode.jsonc`           | `symlink-each` | Preserve the OpenCode configuration and its `~/.agents` skill-script reference without copying credential values.       |
| `~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts` | `yes`   | `no`    | `mise`        | `~/.config/opencode/plugin/env-protection.ts` | `migrate`          | `~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts` | `~/.config/opencode/plugin/env-protection.ts` | `symlink-each` | Preserve the plugin source; its runtime dependency is provided by the target-local package manifest and `node_modules`. |
| `~/dev/personal/dot/home/.config/opencode/tui.json`                 | `yes`   | `no`    | `mise`        | `~/.config/opencode/tui.json`                 | `migrate`          | `~/dev/personal/dot/home/.config/opencode/tui.json`                 | `~/.config/opencode/tui.json`                 | `symlink-each` | Preserve the tracked TUI configuration.                                                                                 |

## Local and runtime inventory

| Path                                                                | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                     | Classification  | Required action | Runtime destination                           | Metadata to preserve                                                                 | Secret or sensitive data |
| ------------------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | --------------- | --------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------ |
| `.config/mise/conf.d/bootstrap-ai.toml`                             | `yes`  | `yes`   | `no`    | `repo`           | The active `bootstrap-ai.toml` declaration links `~/.config/opencode` with `mode = "symlink-each"`; the AI bootstrap test checks this entry.            | `active-global` | `split entry`   | `none`                                        | TOML source; preserve the remaining AI entries until their replacements are selected | `no`                     |
| `~/dev/personal/dot/home/.config/opencode/opencode.jsonc`           | `yes`  | `yes`   | `no`    | `repo`           | `~/.config/opencode/opencode.jsonc` is a relative symlink to this source.                                                                               | `active-global` | `preserve`      | `~/.config/opencode/opencode.jsonc`           | `0644`, `villalj:staff`, relative symlink target                                     | `no`                     |
| `~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts` | `yes`  | `yes`   | `no`    | `repo`           | `~/.config/opencode/plugin/env-protection.ts` is a relative symlink to this source; the plugin imports `@opencode-ai/plugin`.                           | `active-global` | `preserve`      | `~/.config/opencode/plugin/env-protection.ts` | `0644`, `villalj:staff`, relative symlink target                                     | `no`                     |
| `~/dev/personal/dot/home/.config/opencode/tui.json`                 | `yes`  | `yes`   | `no`    | `repo`           | `~/.config/opencode/tui.json` is a relative symlink to this source.                                                                                     | `active-global` | `preserve`      | `~/.config/opencode/tui.json`                 | `0644`, `villalj:staff`, relative symlink target                                     | `no`                     |
| `~/.config/opencode`                                                | `yes`  | `no`    | `no`    | `target`         | Physical directory containing the three managed relative symlinks plus physical `package.json`, `bun.lock`, `node_modules`, and the `plugin` directory. | `mixed`         | `preserve`      | `~/.config/opencode`                          | `0755`, `villalj:staff`, physical directory; preserve unmanaged runtime children     | `no`                     |
| `~/.config/opencode/package.json`                                   | `yes`  | `no`    | `no`    | `target`         | Target-local runtime manifest declares `@opencode-ai/plugin`; it is not present in the tracked source boundary.                                         | `active-global` | `preserve`      | `~/.config/opencode/package.json`             | `0644`, `villalj:staff`, physical file                                               | `no`                     |
| `~/.config/opencode/bun.lock`                                       | `yes`  | `no`    | `no`    | `target`         | Target-local lock file supports the runtime dependency installation; it is not present in the tracked source boundary.                                  | `active-global` | `preserve`      | `~/.config/opencode/bun.lock`                 | `0644`, `villalj:staff`, physical file                                               | `no`                     |
| `~/.config/opencode/node_modules`                                   | `yes`  | `no`    | `no`    | `target`         | Target-local installed dependency tree contains `@opencode-ai/plugin`; it is not present in the tracked source boundary.                                | `active-global` | `preserve`      | `~/.config/opencode/node_modules`             | `0755`, `villalj:staff`, physical directory                                          | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- ~/dev/personal/dot/home/.config/opencode
# no output

git check-ignore -v ~/dev/personal/dot/home/.config/opencode/opencode.jsonc
git check-ignore -v ~/dev/personal/dot/home/.config/opencode/tui.json
git check-ignore -v ~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts
# no output; all three source files are tracked
```

The target package manifest, lock file, and `node_modules` directory are
outside the repository. Do not copy their contents into tracked sources or
print credential-bearing contents.

## Ownership and cutover

- Current target shape: `physical directory with per-file relative links and physical runtime files`
- Current target manifest path: `~/.config/opencode`; managed children resolve to `~/dev/personal/dot/home/.config/opencode`, while `package.json`, `bun.lock`, and `node_modules` remain physical
- Old owner cleanup command: `mise bootstrap dotfiles unapply --dry-run`
- New owner dry-run command: `mise -E opencode bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E opencode bootstrap dotfiles apply --yes`
- Duplicate-owner check: `test "$(grep -RhoF '"~/.config/opencode"' .config/mise/conf.d ~/dev/personal/dot/home/.config/mise/conf.d 2>/dev/null | wc -l | tr -d ' ')" -eq 1`
- Target-content disposition check: `python3 -c 'from pathlib import Path; p = Path.home() / ".config/opencode"; assert {x.name for x in p.iterdir()} == {"opencode.jsonc", "tui.json", "plugin", "package.json", "bun.lock", "node_modules"}'`
- Relative-link check: `python3 -c 'from pathlib import Path; home = Path.home() / ".config/opencode"; source = Path.home() / "dev/personal/dot/home/.config/opencode"; expected = {"opencode.jsonc": source / "opencode.jsonc", "tui.json": source / "tui.json", "plugin/env-protection.ts": source / "plugin/env-protection.ts"}; assert all((home / name).is_symlink() and not (home / name).readlink().is_absolute() and (home / name).resolve() == target for name, target in expected.items())'`

Keep the aggregate declaration until the replacement module exists and the
target-scoped dry run names only the intended OpenCode links. The replacement
must not manage `package.json`, `bun.lock`, or `node_modules`.

## Coupling

- Scripts:
  - `scripts/mise.zsh` applies the existing mise dotfiles phase after package, workspace, tool, and repository bootstrap; no OpenCode-specific phase is required.
  - `tests/scripts/test_mise_bootstrap_opencode.zsh` checks the three tracked OpenCode source files, the module declaration, and the exclusion of `package.json` and `bun.lock`.
- Environment variables:
  - `DOT_PROFILE` selects the rendered profile; `MISE_ENV` selects the focused `opencode` module during validation.
  - No OpenCode-specific environment variable is declared by this boundary.
- Includes or external paths:
  - `~/dev/personal/dot/home/.config/opencode/opencode.jsonc` references `~/.agents/skills/opencode-copilot-multipliers/scripts/sync-opencode-copilot-multipliers.ts*`.
  - `~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts` requires the target-local `@opencode-ai/plugin` dependency.
  - The OpenCode executable is declared by `.config/mise/conf.d/tools.toml` and pinned in `.config/mise/mise.lock`; keep those tool resources outside this dotfile module.
- Other modules:
  - `MIG-MODULE-mise` provides the control plane and `env_conf_d` loading.
  - `MIG-MODULE-agents` provides the `~/.agents` skill path referenced by `opencode.jsonc`.
  - `MIG-MODULE-tools` provides the OpenCode executable; the runtime package files remain target-owned.
  - No authentication files belong in this module.
- User-facing behavior:
  - Preserve the OpenCode model, permission, sharing, TUI theme, and environment-protection behavior.
  - Keep application-owned runtime dependencies in `~/.config/opencode` while mise manages only the tracked configuration and plugin source files.
  - Preserve live source visibility through relative per-file links.

## Validation

- Syntax or source checks:
  - `git ls-files --error-unmatch ~/dev/personal/dot/home/.config/opencode/opencode.jsonc ~/dev/personal/dot/home/.config/opencode/tui.json ~/dev/personal/dot/home/.config/opencode/plugin/env-protection.ts`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/opencode.md`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_opencode.zsh`
- Target smoke test:
  - `mise -E opencode bootstrap dotfiles status`
  - `mise -E opencode bootstrap dotfiles apply --dry-run`
  - The OpenCode CLI smoke test is deferred until the module declaration exists; the current target-link and runtime-content checks remain available.
- Security or token check:
  - `! git grep -IlE 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|(^|[^[:alnum:]])(token|password|secret|api[-_]?key)[[:space:]]*[:=]' -- ~/dev/personal/dot/home/.config/opencode`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-ai.toml`, the three tracked source files, the current per-file target symlink manifest, and the target-local `package.json`, `bun.lock`, and `node_modules`.
- Rollback dry run:
  - `mise -E opencode bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise -E opencode bootstrap dotfiles unapply --yes && mise bootstrap dotfiles apply --yes`
- Stop condition:
  - Stop if the target contains unexpected children, if a managed link is absolute or resolves outside `~/dev/personal/dot/home/.config/opencode`, if the runtime manifest, lock file, or dependency tree would be removed, if two declarations claim the target, or if sensitive values appear in the tracked source boundary.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-ai.toml` currently owns the OpenCode target through a `symlink-each` entry.
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md` maps this boundary to `module.opencode.toml`, the `opencode` environment, and `~/.config/opencode`.
  - `tests/scripts/test_mise_bootstrap_opencode.zsh` verifies the current source set and excludes the target runtime manifest and lock file from the declaration.
  - The current target is a physical directory with three relative managed links and physical runtime dependency files.
- Residual risk:
  - The target-local package manifest, Bun lock file, and `node_modules` must remain unmanaged by mise. Removing or replacing them could break plugin loading even when all tracked links pass.
  - The configuration depends on the separately managed `~/.agents` skill path and on the target-local `@opencode-ai/plugin` installation.
- Open blocker:
  - `none for inventory; migration execution remains pending explicit approval and a reviewed OpenCode target-scoped dry run`
