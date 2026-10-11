# Module Inventory: `agents`

## Metadata

- Module key: `agents`
- Story key: `MIG-MODULE-agents`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/agents.md`
- Current declaration: `.config/mise/conf.d/bootstrap-ai.toml`
- New declaration: `home/.config/mise/conf.d/module.agents.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `~`
- Mise mode: `symlink and symlink-each`
- Environment selector: `agents`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                                                                         | Tracked | Ignored | Current owner | Current target                                         | Target disposition | New source path                                           | New target                                             | New mode       | Notes                                                                                                                                                                        |
| --------------------------------------------------------------------------------------------------- | ------- | ------- | ------------- | ------------------------------------------------------ | ------------------ | --------------------------------------------------------- | ------------------------------------------------------ | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/bootstrap-ai.toml`                                                             | `yes`   | `no`    | `mise`        | `~/.config/mise/conf.d/bootstrap-ai.toml`              | `migrate`          | `home/.config/mise/conf.d/module.agents.toml`             | `~/.config/mise/conf.d/module.agents.toml`             | `bootstrap`    | Split the aggregate AI declaration into the selectable `agents` module.                                                                                                      |
| `home/AGENTS.md`                                                                                    | `yes`   | `no`    | `mise`        | `~/AGENTS.md`                                          | `migrate`          | `home/AGENTS.md`                                          | `~/AGENTS.md`                                          | `symlink`      | Preserve the live relative symlink to the shared global instruction source.                                                                                                  |
| `home/AGENTS.md`                                                                                    | `yes`   | `no`    | `mise`        | `~/CLAUDE.md`                                          | `migrate`          | `home/AGENTS.md`                                          | `~/CLAUDE.md`                                          | `symlink`      | Both global instruction targets intentionally use the same source file.                                                                                                      |
| `home/.agents`                                                                                      | `yes`   | `yes`   | `mise`        | `~/.agents`                                            | `migrate`          | `home/.agents`                                            | `~/.agents`                                            | `symlink-each` | The directory contains tracked skills and durable metadata plus ignored generated output; exclude `skills/**/evals/**/outputs/**` and `eval-workspaces/**/outputs/**`.       |
| `home/.agents/skills/**/evals/**/outputs/**`                                                        | `no`    | `yes`   | `mise`        | `~/.agents/skills/**/evals/**/outputs/**`              | `exclude`          | `none`                                                    | `none`                                                 | `none`         | The 64 generated output files are currently linked by the aggregate declaration but must remain repository-local and unmanaged.                                              |
| `home/.agents/skills/**/evals/evals.json`                                                           | `yes`   | `no`    | `mise`        | `~/.agents/skills/**/evals/evals.json`                 | `migrate`          | `home/.agents/skills/**/evals/evals.json`                 | `~/.agents/skills/**/evals/evals.json`                 | `symlink-each` | Preserve tracked evaluation definitions without copying their contents into this inventory; `skills/agentic-projects/evals/evals.json` is currently missing from the target. |
| `home/.agents/skills/**/evals/**/{benchmark.json,feedback.json,grading.json,manifest.json}`         | `yes`   | `no`    | `mise`        | `~/.agents/skills/**/evals/**`                         | `migrate`          | `home/.agents/skills/**/evals/**`                         | `~/.agents/skills/**/evals/**`                         | `symlink-each` | Preserve tracked durable evaluation metadata without copying its contents into this inventory.                                                                               |
| `home/.agents/skills/pr-guidelines/evals/discoverability/{queries.json,results.json}`               | `yes`   | `no`    | `mise`        | `~/.agents/skills/pr-guidelines/evals/discoverability` | `migrate`          | `home/.agents/skills/pr-guidelines/evals/discoverability` | `~/.agents/skills/pr-guidelines/evals/discoverability` | `symlink-each` | Preserve the tracked discoverability metadata as part of the skill evaluation manifest.                                                                                      |
| `home/.agents/eval-workspaces/**/{benchmark.json,feedback.json,grading-summary.json,manifest.json}` | `yes`   | `no`    | `mise`        | `~/.agents/eval-workspaces/**`                         | `migrate`          | `home/.agents/eval-workspaces`                            | `~/.agents/eval-workspaces`                            | `symlink-each` | Preserve the 12 tracked durable metadata files; the current status reports these files as missing from the target.                                                           |
| `home/.agents/eval-workspaces/**/outputs/**`                                                        | `no`    | `yes`   | `mise`        | `~/.agents/eval-workspaces/**/outputs/**`              | `exclude`          | `none`                                                    | `none`                                                 | `none`         | Keep the reserved generated-output boundary unmanaged even when future evaluation runs create files there.                                                                   |

## Local and runtime inventory

| Path                                                                                                | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                                                                           | Classification   | Required action               | Runtime destination                                    | Metadata to preserve                                                                   | Secret or sensitive data |
| --------------------------------------------------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------ |
| `home/AGENTS.md`                                                                                    | `yes`  | `yes`   | `no`    | `repo`           | `bootstrap-ai.toml` declares both global instruction links; `~/AGENTS.md` and `~/CLAUDE.md` resolve to this source                                                                                            | `active-global`  | `preserve`                    | `~/AGENTS.md` and `~/CLAUDE.md`                        | Regular file mode `0644`; relative symlinks                                            | `no`                     |
| `home/.agents/skills/**`                                                                            | `yes`  | `yes`   | `yes`   | `repo`           | `bootstrap-ai.toml` declares `~/.agents` with `symlink-each`; the target contains per-file links to skill sources                                                                                             | `active-global`  | `migrate with exclusion`      | `~/.agents/skills/**`                                  | Directory structure, tracked skill files, durable metadata, and relative links         | `unknown`                |
| `home/.agents/skills/**/evals/**/outputs/**`                                                        | `yes`  | `no`    | `yes`   | `repo`           | Git global ignore excludes the generated output boundary; 64 output files are currently linked below `~/.agents`                                                                                              | `stray`          | `exclude`                     | `none`                                                 | Ignore provenance and generated-file paths only; do not copy contents                  | `unknown`                |
| `home/.agents/skills/**/evals/evals.json`                                                           | `yes`  | `yes`   | `no`    | `repo`           | Tracked evaluation definitions are present for the skills with evaluation suites                                                                                                                              | `active-global`  | `preserve`                    | `~/.agents/skills/**/evals/evals.json`                 | Tracked JSON metadata paths and relative links; contents remain outside this inventory | `unknown`                |
| `home/.agents/skills/**/evals/**/{benchmark.json,feedback.json,grading.json,manifest.json}`         | `yes`  | `yes`   | `no`    | `repo`           | Tracked evaluation metadata exists in skill-local `evals` directories and is part of the current source tree                                                                                                  | `active-global`  | `preserve`                    | `~/.agents/skills/**/evals/**`                         | Tracked JSON metadata paths and relative links; contents remain outside this inventory | `unknown`                |
| `home/.agents/skills/pr-guidelines/evals/discoverability/{queries.json,results.json}`               | `yes`  | `yes`   | `no`    | `repo`           | Tracked discoverability metadata is part of the `pr-guidelines` evaluation suite                                                                                                                              | `active-global`  | `preserve`                    | `~/.agents/skills/pr-guidelines/evals/discoverability` | Tracked JSON metadata paths and relative links; contents remain outside this inventory | `unknown`                |
| `home/.agents/eval-workspaces/**/{benchmark.json,feedback.json,grading-summary.json,manifest.json}` | `yes`  | `yes`   | `no`    | `repo`           | Tracked durable metadata exists under the agent evaluation workspaces; 12 target files in this subtree are missing                                                                                            | `active-global`  | `preserve`                    | `~/.agents/eval-workspaces/**`                         | Tracked JSON metadata paths and relative links; contents remain outside this inventory | `unknown`                |
| `home/.agents/eval-workspaces/**/outputs/**`                                                        | `no`   | `no`    | `yes`   | `repo`           | The global ignore rule reserves this generated-output boundary even though no files exist currently                                                                                                           | `not-applicable` | `exclude`                     | `none`                                                 | Ignore rule and exclusion pattern only                                                 | `unknown`                |
| `~/.agents/skills/{agent-instructions-evaluation,planning}/evals/iteration-*/*`                     | `yes`  | `no`    | `no`    | `target`         | The current target contains 12 broken links to metadata that now resides under `home/.agents/eval-workspaces`; the dry run proposes removing them                                                             | `stray`          | `remove after reconciliation` | `none`                                                 | Preserve the stale-link manifest only until the durable source links are applied       | `unknown`                |
| `~/.agents`                                                                                         | `yes`  | `no`    | `no`    | `target`         | `mise bootstrap dotfiles status` reports the `symlink-each` declaration as applied with 173 files linked and 13 missing; 12 are under `eval-workspaces` and one is `skills/agentic-projects/evals/evals.json` | `active-global`  | `preserve and reconcile`      | `~/.agents`                                            | Existing physical directory, per-file relative links, and unrelated local files        | `unknown`                |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- home/.agents
git check-ignore -v <path>
```

The Git global excludes file is `~/.config/git/ignore`. It ignores
generated files below `**/.agents/skills/**/evals/iteration-*/*` while
re-including durable metadata such as `benchmark.json`, `feedback.json`,
`manifest.json`, and `grading.json`. It also reserves
`**/.agents/eval-workspaces/**/iteration-*/*` and re-includes its durable
metadata files. Do not print evaluation output contents.

## Ownership and cutover

- Current target shape: `physical directory with per-file links; separate file symlinks for AGENTS.md and CLAUDE.md`
- Current target manifest path: `.config/mise/conf.d/bootstrap-ai.toml`
- Old owner cleanup command: `mise bootstrap dotfiles unapply --dry-run`
- New owner dry-run command: `mise bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise bootstrap dotfiles apply`
- Duplicate-owner check: `grep -R -nE '"~/(AGENTS\.md|CLAUDE\.md|\.agents)"' .config/mise/conf.d home/.config/mise/conf.d 2>/dev/null`
- Target-content disposition check: `find "$HOME/.agents" -type l -path '*/evals/*/outputs/*' -print; find "$HOME/.agents/eval-workspaces" -type l -print 2>/dev/null`
- Relative-link check: `find "$HOME/.agents" -type l -exec sh -c 'case "$(readlink "$1")" in /*) exit 1;; esac' _ {} \; && readlink "$HOME/AGENTS.md" && readlink "$HOME/CLAUDE.md"`

## Coupling

- Scripts:
  - `scripts/mise.zsh` already applies `mise bootstrap dotfiles apply --yes` in the dotfiles phase.
  - `scripts/init.zsh --mise` sources `scripts/mise.zsh`; no new initialization phase is required.
- Environment variables:
  - `DOT_PROFILE` selects the persisted profile; the new `agents` environment must be selected by the rendered mise profile configuration.
- Includes or external paths:
  - `home/AGENTS.md` is the shared source for both `~/AGENTS.md` and `~/CLAUDE.md`.
  - `.config/git/ignore` supplies the global ignore rules for generated evaluation output and durable metadata.
- Other modules:
  - `MIG-MODULE-mise` must establish the new mise control plane before this module is selected.
  - `MIG-MODULE-claude` consumes `home/.agents/skills` directly and must use the same `skills/**/evals/**/outputs/**` exclusion for `~/.claude/skills`.
  - `MIG-MODULE-copilot` consumes `home/AGENTS.md` directly for its instructions target.
  - `MIG-MODULE-opencode` remains a separate owner for its application-specific AI target.
- User-facing behavior:
  - Global instructions and skills remain live-linked into the home directory.
  - Tracked skill files and durable evaluation metadata remain available through `~/.agents`.
  - Claude skill links use the canonical `home/.agents/skills` source without generated evaluation output.
  - Generated evaluation output is no longer bootstrapped or linked into `~/.agents`.

## Validation

- Syntax or source checks:
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/agents.md`
  - `mise run lint-skill-index --base-path .`
  - `mise run lint-skill-index --base-path home`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_agents.zsh`
- Target smoke test:
  - `mise bootstrap dotfiles status`
  - `mise bootstrap dotfiles apply --dry-run`
  - Verify that the dry run excludes `skills/**/evals/**/outputs/**` and `eval-workspaces/**/outputs/**`.
  - Verify that the Claude module uses the canonical skills source and excludes `skills/**/evals/**/outputs/**`.
- Security or token check:
  - `grep -Eiq '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY)' .agents/projects/stow-to-mise-migration/research/inventories/agents.md && exit 1 || true`
  - Do not print or copy evaluation output contents.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-ai.toml`
  - `home/AGENTS.md` and `home/.agents`
  - Existing relative links at `~/AGENTS.md`, `~/CLAUDE.md`, and below `~/.agents`
  - The 64 ignored generated output files and their repository-local paths
- Rollback dry run:
  - Restore the aggregate declaration, then run `mise bootstrap dotfiles apply --dry-run`
- Rollback apply:
  - Restore the aggregate declaration and run `mise bootstrap dotfiles apply`
- Stop condition:
  - Stop if the dry run links any generated evaluation output, proposes deleting an unrelated target file, fails to restore the 12 durable metadata links, or shows both the aggregate and module declarations owning the same target.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-ai.toml`
  - `home/AGENTS.md`
  - `home/.agents`
  - `.stow-local-ignore`
  - `~/.config/git/ignore`
  - `AGENTS.md`
  - `home/AGENTS.md`
  - `.config/mise/tasks/lint-skill-index.zsh`
  - `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`
- Residual risk:
  - The current aggregate declaration links 64 ignored generated evaluation
    output files into `~/.agents`; the new `exclude` patterns must be verified
    before applying the split module.
  - The current status reports 13 tracked files missing from the target: 12
    durable evaluation metadata files under `eval-workspaces` and
    `skills/agentic-projects/evals/evals.json`. The dry run proposes removing
    12 stale links from their former skill-local paths. Reconcile all missing
    sources before accepting those removals.
  - Evaluation metadata and generated output can contain sensitive data; this
    inventory records paths and classifications only.
  - The baseline `stow -nvR .` check is available after the obsolete Copilot
    repository boundary was removed.
  - The Claude module must preserve the same generated-output exclusion when it
    consumes `home/.agents/skills` directly.
- Open blocker:
  - `none for inventory; migration execution remains pending explicit approval and a reviewed mise dry run`
