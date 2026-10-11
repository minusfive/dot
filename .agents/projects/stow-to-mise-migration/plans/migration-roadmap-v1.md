# Stow to mise migration roadmap

## Objective

Move eligible global configuration from `.config/` to `~/dev/personal/dot/home/` without:

- exposing runtime or credential data;
- losing local application state;
- creating dual ownership;
- changing unrelated bootstrap behavior; or
- removing configuration without an approved disposition.

Keep `~/dev/personal/dot/home/.config/mise/` as the tracked source for the global `mise` control
plane. Transfer `~/.config/mise/` from GNU Stow to `mise` in the control-plane
story. Keep application runtime files outside tracked sources and `mise`
declarations.

This roadmap is the execution source of truth for story scope, execution
order, steps, acceptance checks, and rollback. The module stories appear in
execution order. That order is the only ordering metadata for the migration.
The dependency fields in each story are checked views of the canonical graph
in `module-registry.toml`. The research matrix records supporting evidence.
Each module story owns one inventory file and one approval record.

## Plan metadata

- Plan path: `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`
- Module registry: `.agents/projects/stow-to-mise-migration/module-registry.toml`
- Inventory template: `.agents/projects/stow-to-mise-migration/templates/module-inventory.md`
- Story template: `.agents/projects/stow-to-mise-migration/templates/module-story.md`
- Agent prompt: `.agents/projects/stow-to-mise-migration/templates/module-migration-agent-prompt.md`
- Approval template: `.agents/projects/stow-to-mise-migration/templates/approval-record.md`
- Baseline template: `.agents/projects/stow-to-mise-migration/templates/baseline-record.md`
- Artifact validator: `.agents/projects/stow-to-mise-migration/scripts/validate-artifacts.zsh`
- Planning work: `.agents/projects/stow-to-mise-migration/research/planning-work.md`
- Pending decisions: `.agents/projects/stow-to-mise-migration/research/pending-decisions.md`
- Config cleanup review: `.agents/projects/stow-to-mise-migration/research/config-cleanup-review.md`
- Approval directory: `.agents/projects/stow-to-mise-migration/research/approvals/`
- Inventory directory: `.agents/projects/stow-to-mise-migration/research/inventories/`
- Status: `blocked`

No migration mutation is authorized until the required approval record is
complete for that story.

## Canonical reference hierarchy

Use these references in this order:

1. This roadmap controls story scope, steps, acceptance checks, rollback, and
   sequencing.
2. The module inventory controls observed source paths, target paths, runtime
   paths, ownership facts, and approved path dispositions.
3. The approval record controls authorization for the story's exact scope.
4. The baseline record controls run-specific state and expected differences.
5. The module registry controls module coverage, the canonical dependency
   graph, and dependency identifiers.
6. Templates control document format only.
7. Research files provide background evidence. They do not override this
   roadmap or an approved module inventory.

If two references conflict, stop the story and record drift in
`.agents/projects/stow-to-mise-migration/research/pending-decisions.md`.
Do not choose a value during execution.

## Execution entry criteria

Before the first execution story enters `todo`, complete the planning work in
`.agents/projects/stow-to-mise-migration/research/planning-work.md`.

The entry criteria are:

- `pending-decisions.md` has no pending records;
- the baseline packet is complete;
- the artifact validator passes;
- every module inventory is complete;
- the Copilot and Claude inventories use the canonical source paths and
  classify their nested aliases as repository-only;
- every mutation story has an approved scope; and
- the user has approved this exact roadmap path for execution.

## Shared invariants

### Inventory contract

Each inventory must use the exact headings and columns in the inventory
template. It must include:

- every tracked source path;
- every ignored path;
- every non-ignored untracked path;
- every current target path;
- every target-only file visible through a parent symlink;
- the current owner and target shape;
- the new source, target, and mode;
- runtime and secret classification;
- coupling and validation commands;
- rollback commands; and
- an explicit `migrate`, `preserve`, `remove`, `repository-only`, or `unknown`
  disposition for every path.

Use these commands for every source boundary:

```bash
git ls-files -- <source-boundary>
git ls-files --others --ignored --exclude-standard -- <source-boundary>
git ls-files --others --exclude-standard -- <source-boundary>
git check-ignore -v <path>
```

The second command is required. The third command alone does not list ignored
files.

Do not print credential-bearing contents. Record names, metadata, references,
checksums, and command results instead.

### Canonical source paths

When a tracked source path is itself a symlink to another tracked source path,
use the resolved canonical path as the new `mise` source. Do not create a new
target link through an alias in `~/dev/personal/dot/home/`; the module must map the target
directly to the canonical source and must not include the alias as a second
managed source.

When a declaration is loaded from `~/.config/mise/conf.d`, use an explicit
source path rooted at `~/dev/personal/dot/home/...`. Do not set
`dotfiles.root` for this migration. Relative source values resolve from the
live target configuration directory, not from the repository copy.

The current source-path corrections are:

- Copilot: map `~/.copilot/copilot-instructions.md` directly to
  `~/dev/personal/dot/home/AGENTS.md`. Do not use `~/dev/personal/dot/home/.copilot/copilot-instructions.md` as the
  new source.
- Claude: map `~/.claude/skills` directly to `~/dev/personal/dot/home/.agents/skills`. Do not use
  `~/dev/personal/dot/home/.claude/skills` as the new source; it is only a cross-module alias to
  the agents source.
- WezTerm: `.config/wezterm/CLAUDE.md` resolves to the sibling
  `.config/wezterm/AGENTS.md`, but both files are excluded from the migration
  source set by `.stow-local-ignore`; no new `~/dev/personal/dot/home/` source is required.

Before execution, reconcile the Copilot and Claude inventories with these
canonical paths and classify their nested aliases as repository-only. The
focused module declarations must use explicit target entries where a
directory source would otherwise redeploy an alias.

### Target manifest

Before an ownership change, record a manifest of the complete target tree.
Follow symlinks only to identify the current source. Record:

- target path and type;
- resolved source;
- owner;
- mode, owner, group, and permissions;
- tracked, ignored, or untracked state;
- target-only entries; and
- the approved disposition.

Do not switch a whole-directory symlink to `symlink-each` until every
target-only entry has a disposition. A parent symlink can expose files that
Stow does not link individually.

### Ownership transition

Use this procedure for a Stow-to-`mise` boundary:

1. Confirm the module approval record.
2. Read the module inventory.
3. Save the source and target manifests.
4. Copy only the approved tracked source set into `~/dev/personal/dot/home/`.
5. Preserve file modes, owners, groups, symlink targets, and timestamps where
   the inventory requires them.
6. Run syntax, source, exclusion, and security checks.
7. Run a target-scoped `mise dot apply --dry-run <target>`.
8. Stop when the dry run names an unexpected target, source, or owner.
9. Inspect the target and confirm its recorded disposition.
10. Remove only the confirmed Stow link.
11. Create the detached target directory.
12. Move preserved local runtime files into the detached target.
13. Never copy a sensitive runtime file without erasing the old copy and
    asserting that the old path is absent.
14. Apply the target-scoped `mise` declaration.
15. Verify one-owner state, relative links, target contents, permissions, and
    behavior.
16. Save the post-transition manifest.
17. Restore the old owner when any acceptance check fails.

Use `dotfiles.relative_symlinks = true` before the first `mise` apply.

### Declaration transition

Use this procedure for an existing `mise` declaration that changes file
ownership or resource type:

1. Read the module inventory and legacy declaration.
2. Record the old target and resource manifests.
3. Create the new declaration in an inactive environment file.
4. Preview the legacy cleanup with the exact command in the inventory.
5. Apply the cleanup only after the output names the intended targets.
6. Remove the old declaration from the active source set.
7. Activate the new environment only after all source files exist.
8. Run the focused test and target-scoped dry run.
9. Record the post-transition status and rollback reference.

Do not create an active duplicate declaration for a target.

### Legacy `bootstrap` cleanup

The existing `bootstrap-ai.toml`, `bootstrap-gh.toml`,
`bootstrap-packages.toml`, `bootstrap-packages.personal.toml`,
`bootstrap-repos.toml`, and `tools.toml` files are base `conf.d` declarations.
Their filenames are not valid arguments to `mise bootstrap unapply`.

For a legacy `[bootstrap.files]`, `[bootstrap.directories]`, or
`[bootstrap.repos]` entry:

1. Copy only the relevant old sections to a temporary
   `config.migration-legacy-<module>.toml` file outside the repository.
2. Set `MISE_CONFIG_DIR` to the temporary configuration directory.
3. Run `mise bootstrap unapply migration-legacy-<module> --dry-run`.
4. Apply the unapply only when the output names the intended targets.
5. Remove the temporary configuration directory.
6. Confirm that the old declaration is still available for rollback until the
   new declaration passes its focused checks.

For a legacy `[dotfiles]` entry, run a target-scoped
`mise dot unapply --dry-run <target>` while the legacy declaration is the only
active owner. Do not load the new module environment until the old target is
clean.

### Security and local-state rules

- Keep authentication databases, WAL files, histories, completion dumps,
  caches, dependencies, lockfiles, and generated output outside `~/dev/personal/dot/home/`
  unless the inventory explicitly approves repository ownership.
- Keep `.config/zsh/.zsh_history` and `.config/zsh/.zcompdump` outside
  `~/dev/personal/dot/home/`. Move them into the detached runtime target before removing the
  parent Stow link.
- Treat a mixed boundary as separate local files. Keep active files at their
  runtime destination and remove only proven stray residue.
- Do not use `stow --adopt`.
- Do not use `mise dot apply` without a target during a cutover.
- Do not print credentials or database contents during validation.

### Approval and baseline records

Create one approval record per story under
`.agents/projects/stow-to-mise-migration/research/approvals/`.

Each record must contain:

- story and module keys;
- inventory path;
- approver and approval time;
- exact approved scope;
- baseline record;
- dry-run record;
- focused test;
- rollback record; and
- final decision.

Create one baseline record per story run from the baseline template. Include
the `mise` and Stow versions, profile, commands, output paths, source
manifests, target manifests, pre-existing differences, expected differences,
and unexpected differences.

Resolved planning rule `DEC-focused-test-surface`: each module story must name
exactly one focused test path. The focused test must cover only that module.
Aggregate checks cannot replace the module test.

The final apply has its own approval record. Approval for a module does not
authorize the final full bootstrap.

### Common validation gates

Run the artifact validator before execution:

```bash
.agents/projects/stow-to-mise-migration/scripts/validate-artifacts.zsh
```

After each ownership transition, run the target-scoped status and dry-run
checks in the module inventory. Also run:

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --dry-run
stow -nvR .
```

Run the assigned module-focused test before aggregate checks. Use `mise run
check` at the checkpoints defined by the plan. Use `./scripts/init.zsh --mise`
only as the separately approved full-flow integration test.

### Future migration-agent prompt

Use the prompt in
`.agents/projects/stow-to-mise-migration/templates/module-migration-agent-prompt.md`
for future execution agents. The prompt restricts each agent to one inventory
file, requires ignored-file discovery, forbids secret output, and requires
explicit target dispositions.

The current inventory run tests this prompt. The artifact validator
must pass before the prompt is accepted for future use.

## Strict sequencing

The execution graph is:

1. Complete the execution entry criteria.
2. `MIG-MODULE-mise` transfers the global `mise` control plane.
3. Complete every remaining module story in the listed order.
4. `MIG-90` performs final profile activation and validation.

The module story sections below define the strict execution order. Start a
story only after the preceding story passes its acceptance checks. Dependencies
remain required prerequisites, but they do not permit a later story to start
early. No other artifact supplies sequence metadata.

Run every normal story phase in order: inventory and read-only inspection,
source preparation, declaration authoring, ownership transition, and
validation. If a check fails, run that story's rollback procedure. Retain
rollback artifacts until the acceptance checks pass. Remove them only in the
story's explicit cleanup step or after final closeout. Run one module agent at
a time. Do not run parallel jobs or agents for this project.

## Shared story contract

Every story uses this contract unless its story text adds a stricter rule.

### Common phases

1. Read the assigned inventory, approval record, and baseline.
2. Save the required source and target manifests.
3. Run the inventory's syntax, source, exclusion, and security checks.
4. Apply the target-scoped declaration or ownership transition.
5. Run the inventory's focused test and target smoke checks.
6. Record the result and preserve rollback artifacts until acceptance passes.

Each module story owns its preparation steps, focused test, target smoke
checks, and rollback artifacts. Focused tests must cover one module only.
Split existing aggregate tests before the related module story enters
execution. Do not create shared preparation steps, tests, or acceptance gates.

Each story lists its module-specific actions and any explicit checkpoints.
Common rollback and acceptance rules do not need to be repeated.

### Common acceptance checks

Every story must have one owner, use only its approved source set, keep runtime
and sensitive files at approved destinations, and pass its focused test.
Story acceptance sections list only module-specific checks.

### Common rollback contract

If an acceptance check fails, stop the story. Run the exact inventory rollback
dry run. Restore only this story's prior owner, source, target, and preserved
runtime files. Retain manifests and rollback records until the story passes or
the final closeout records the failure. Story rollback sections list only
module-specific recovery rules.

## 1. Story `MIG-MODULE-mise`: Transfer the global mise control plane

### Metadata — `MIG-MODULE-mise`

- Module key: `mise`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/mise.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-mise.md`
- Planning gate: `DEC-mise-control-plane-transition-mechanism` is resolved;
  retain the temporary bridge for the cutover.
- Source-path decision `DEC-mise-control-plane-source-resolution`: use
  explicit `~/dev/personal/dot/home/...` values for declarations loaded from
  `~/.config/mise/conf.d`; do not set `dotfiles.root`.
- Dependencies: `none`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/mise`
- Target: `~/.config/mise`
- Mode: one explicit `symlink` entry per tracked source file
- Risk: `critical`
- Status: `blocked`

### Description — `MIG-MODULE-mise`

Move the tracked global `mise` source tree into `~/dev/personal/dot/home/.config/mise` and make
`mise` own the target. This story owns only the global control-plane files and
`module.mise.toml`. Later module stories own their declarations. Preserve the
lockfile, task files, utilities, local variants, and profile rendering behavior
without copying ignored local files.

### Steps — `MIG-MODULE-mise`

1. Read the inventory and save the complete source and target manifests.
2. Copy the tracked control-plane files into `~/dev/personal/dot/home/.config/mise`.
3. Retain the temporary bridge for the cutover.
4. Run `mise trust --yes ~/dev/personal/dot`.
5. Run `mise -C ~/dev/personal/dot dot apply --dry-run ~/.config/mise`.
6. Detach the confirmed Stow directory link.
7. Move preserved local files into the detached target.
8. Apply the temporary bridge with the same target scope.
9. Prepare only the temporary transition artifacts required by this story
   before changing `miserc.toml`.
10. Generate `module.mise.toml` from the saved manifest and deliberate new
    control-plane files. Use explicit `~/dev/personal/dot/home/...` source
    values for every declaration loaded from `~/.config/mise/conf.d`.
11. Retain temporary transition artifacts and saved manifests until the final
    target-scoped apply and focused test pass.
12. Apply the final target-scoped declaration.
13. Remove `MISE_ENV` export and log from `scripts/mise.zsh`.
14. Apply dotfiles before workspace profile trust.
15. Remove temporary transition artifacts only after the final target-scoped
    apply and focused test pass.

### Acceptance checks — `MIG-MODULE-mise`

- Every tracked control-plane file has one relative `mise` symlink.
- Local variants remain outside repository ownership.
- The final declaration has no duplicate target.
- No declaration owned by a later module story is created or selected.
- The selected transition mechanism and final apply affect only
  `~/.config/mise`.
- Both profile branches render module files that exist.
- The dotfiles phase runs before workspace profile trust.

### Rollback and mitigation — `MIG-MODULE-mise`

Use the common rollback contract. Retain the control-plane artifacts until final acceptance.

## 2. Story `MIG-MODULE-copilot`: Transfer the Copilot module

### Metadata — `MIG-MODULE-copilot`

- Module key: `copilot`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/copilot.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-copilot.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mixed`
- New owner: `mise` for `~/.copilot`
- Source: `~/dev/personal/dot/home/AGENTS.md` and `~/dev/personal/dot/home/.copilot/statusline-context.sh`
- Target: `~/.copilot`
- Mode: explicit per-target symlinks for `~/.copilot`; unmanaged runtime state
- Risk: `critical`
- Status: `blocked`

### Description — `MIG-MODULE-copilot`

Transfer the two managed `~/.copilot` files to `mise`. Keep the
repository-only alias outside the module source set.

### Steps — `MIG-MODULE-copilot`

1. Read the approved Copilot inventory and approval record.
2. Create the `~/.copilot` module with explicit target entries for
   `copilot-instructions.md` and `statusline-context.sh`. Source the
   instructions target from `~/dev/personal/dot/home/AGENTS.md`, not from the nested
   `~/dev/personal/dot/home/.copilot/copilot-instructions.md` alias:

   ```toml
   [dotfiles]
   "~/.copilot/copilot-instructions.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }
   "~/.copilot/statusline-context.sh" = { source = "~/dev/personal/dot/home/.copilot/statusline-context.sh", mode = "symlink" }
   ```

3. Apply the `~/.copilot` module.
4. Run the focused AI configuration test and `stow -nvR .`.

### Acceptance checks — `MIG-MODULE-copilot`

- `~/.copilot/copilot-instructions.md` has a direct `~/dev/personal/dot/home/AGENTS.md` source;
  the nested Copilot alias is not managed by the module.
- No repository-side Copilot runtime boundary remains.
- The Stow dry run reports no conflict for the Copilot source boundary.

### Rollback and mitigation — `MIG-MODULE-copilot`

Use the common rollback contract. Do not delete an active file.

## 3. Story `MIG-MODULE-agents`: Transfer the agents module

### Metadata — `MIG-MODULE-agents`

- Module key: `agents`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/agents.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-agents.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mise` through `bootstrap-ai.toml`
- New owner: `mise`
- Source: `~/dev/personal/dot/home/AGENTS.md` and `~/dev/personal/dot/home/.agents`
- Target: `~/AGENTS.md`, `~/CLAUDE.md`, and `~/.agents`
- Mode: `symlink` and `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-agents`

Split the shared agent files from the old AI aggregate into `module.agents.toml`.
Exclude generated evaluation output while preserving tracked skills and durable
evaluation metadata.

### Steps — `MIG-MODULE-agents`

1. Read the inventory and target manifest.
2. Use the legacy dotfile cleanup procedure before activating the module.
3. Create the module with the approved source paths and output exclusions.
4. Apply only the agents targets.
5. Run skill-index tests and target checks.

### Acceptance checks — `MIG-MODULE-agents`

- `~/AGENTS.md`, `~/CLAUDE.md`, and `~/.agents` have one owner.
- Generated evaluation output has no deployed link.
- Tracked skills and approved metadata remain available.

### Rollback and mitigation — `MIG-MODULE-agents`

Use the common rollback contract.

## 4. Story `MIG-MODULE-claude`: Transfer the Claude module

### Metadata — `MIG-MODULE-claude`

- Module key: `claude`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/claude.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-claude.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mise` through `bootstrap-ai.toml`
- New owner: `mise`
- Source: `~/dev/personal/dot/home/.claude/settings.json`, `~/dev/personal/dot/home/.claude/statusline-command.sh`,
  and `~/dev/personal/dot/home/.agents/skills`
- Target: `~/.claude`
- Mode: explicit per-target symlinks; unmanaged runtime state
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-claude`

Move Claude configuration into its own module. Keep settings and statusline
references, map the skills target directly to `~/dev/personal/dot/home/.agents/skills`, and
exclude runtime state and the nested `~/dev/personal/dot/home/.claude/skills` alias.

### Steps — `MIG-MODULE-claude`

1. Read the inventory and target manifest.
2. Use the legacy dotfile cleanup procedure.
3. Create `module.claude.toml` with explicit target entries for settings,
   statusline, and `~/.claude/skills`. Source the skills target directly from
   `~/dev/personal/dot/home/.agents/skills`, not from `~/dev/personal/dot/home/.claude/skills`:

   ```toml
   [dotfiles]
   "~/.claude/settings.json" = { source = "~/dev/personal/dot/home/.claude/settings.json", mode = "symlink" }
   "~/.claude/skills" = { source = "~/dev/personal/dot/home/.agents/skills", mode = "symlink-each", exclude = ["**/evals/**/outputs/**"] }
   "~/.claude/statusline-command.sh" = { source = "~/dev/personal/dot/home/.claude/statusline-command.sh", mode = "symlink" }
   ```

4. Apply the Claude module.
5. Run the focused AI test and target checks.

### Acceptance checks — `MIG-MODULE-claude`

- Every managed `~/.claude/skills` link resolves directly to
  `~/dev/personal/dot/home/.agents/skills`, without the nested Claude alias.
- Generated evaluation output has no deployed link under `~/.claude/skills`.
- Runtime state is outside tracked sources.
- Statusline references remain valid.

### Rollback and mitigation — `MIG-MODULE-claude`

Use the common rollback contract.

## 5. Story `MIG-MODULE-opencode`: Transfer the OpenCode module

### Metadata — `MIG-MODULE-opencode`

- Module key: `opencode`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/opencode.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-opencode.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mise` through `bootstrap-ai.toml`
- New owner: `mise`
- Source: `~/dev/personal/dot/home/.config/opencode`
- Target: `~/.config/opencode`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-opencode`

Move OpenCode configuration into its own module. Keep the plugin sources and
tracked configuration. Exclude package manifests, locks, and runtime state.

### Steps — `MIG-MODULE-opencode`

1. Read the inventory and target manifest.
2. Use the legacy dotfile cleanup procedure.
3. Create and apply `module.opencode.toml`.
4. Run the focused AI test and target checks.

### Acceptance checks — `MIG-MODULE-opencode`

- Runtime package files are not managed.
- Plugin sources remain available.

### Rollback and mitigation — `MIG-MODULE-opencode`

Use the common rollback contract.

## 6. Story `MIG-MODULE-gh`: Transfer the GitHub configuration module

### Metadata — `MIG-MODULE-gh`

- Module key: `gh`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/gh.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-gh.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mise` through legacy `[bootstrap.files]`
- New owner: `mise`
- Source: `~/dev/personal/dot/home/.config/gh/personal/hosts.yml`
- Target: `~/.config/gh/personal/hosts.yml`
- Mode: `symlink`, plus a directory mode resource
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-gh`

Move the GitHub hosts file from `[bootstrap.files]` to `[dotfiles]`. Keep the
directory mode declaration. Keep the source token-free.

### Steps — `MIG-MODULE-gh`

1. Read the inventory and token-free evidence.
2. Use the temporary legacy bootstrap cleanup procedure.
3. Create `module.gh.toml` with the directory and symlink resources.
4. Apply the target-scoped module.
5. Run the token check and the `gh` module-focused test.

### Acceptance checks — `MIG-MODULE-gh`

- The hosts file contains no token.
- The directory mode remains a bootstrap concern.

### Rollback and mitigation — `MIG-MODULE-gh`

Use the common rollback contract. Restore the old `[bootstrap.files]` declaration and target file.

## 7. Story `MIG-MODULE-profiles`: Transfer workspace profile files

### Metadata — `MIG-MODULE-profiles`

- Module key: `profiles`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/profiles.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-profiles.md`
- Dependencies: `MIG-MODULE-gh`
- Current owner: `mise` through legacy `[bootstrap.files]`
- New owner: `mise`
- Source: `~/dev/personal/dot/home/dev/profile.mise.toml`
- Targets: `~/dev/personal/mise.toml` and `~/dev/work/mise.toml`
- Mode: `template`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-profiles`

Render both workspace profile files from one tracked template. Preserve the
target-specific `GH_CONFIG_DIR` value and trust order.

### Steps — `MIG-MODULE-profiles`

1. Read the inventory and template rendering evidence.
2. Use the temporary legacy bootstrap cleanup procedure.
3. Create `module.profiles.toml`.
4. Render both target files without printing secret values.
5. Update `scripts/mise.zsh` so dotfiles apply before profile trust.
6. Run the profile-order checks and the `profiles` module-focused test.

### Acceptance checks — `MIG-MODULE-profiles`

- Both workspace files render.
- This story is the only migration story that writes the two workspace files.
- Each target receives the correct `GH_CONFIG_DIR`.
- Profile trust runs after dotfiles apply.
- `scripts/mise.zsh` does not export `MISE_ENV`.

### Rollback and mitigation — `MIG-MODULE-profiles`

Use the common rollback contract. Restore the profile trust order.

## 8. Story `MIG-MODULE-packages`: Transfer shared package declarations

### Metadata — `MIG-MODULE-packages`

- Module key: `packages`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/packages.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-packages.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: `mise`
- New owner: `mise`
- Source: `.config/mise/conf.d/bootstrap-packages.toml`
- Target: package resources
- Mode: `[bootstrap.packages]`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-packages`

Rename the shared package declaration to `module.packages.toml`. Preserve
Homebrew adoption, shared formulas, casks, and Mac App Store resources.

### Steps — `MIG-MODULE-packages`

1. Read the exhaustive package inventory.
2. Record the old package baseline.
3. Rename the declaration only after the old resource state is recorded.
4. Keep package cleanup separate from dotfile unapply.
5. Run the `packages` module-focused test.

### Acceptance checks — `MIG-MODULE-packages`

- Every inventory package remains declared.
- Personal-only packages remain outside the shared module.
- No package removal occurs during this declaration transition.

### Rollback and mitigation — `MIG-MODULE-packages`

Use the common rollback contract. Do not prune packages.

## 9. Story `MIG-MODULE-personal-packages`: Transfer personal package declarations

### Metadata — `MIG-MODULE-personal-packages`

- Module key: `personal-packages`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/personal-packages.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-personal-packages.md`
- Dependencies: `MIG-MODULE-packages`
- Current owner: `mise`
- New owner: `mise`
- Source: `.config/mise/conf.d/bootstrap-packages.personal.toml`
- Target: personal package resources
- Mode: `[bootstrap.packages]`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-personal-packages`

Rename the personal package declaration to `module.personal-packages.toml`.
Keep it selected only by the personal profile.

### Steps — `MIG-MODULE-personal-packages`

1. Read the exhaustive package inventory.
2. Record work and personal profile package sets.
3. Rename the declaration.
4. Run the personal and work package status checks without writing either
   workspace profile file.
5. Run the personal package test.

### Acceptance checks — `MIG-MODULE-personal-packages`

- Personal packages load only for the personal profile.
- Shared packages remain in the shared module.
- This story does not write `~/dev/personal/mise.toml` or
  `~/dev/work/mise.toml`.
- No package pruning occurs in this story.

### Rollback and mitigation — `MIG-MODULE-personal-packages`

Use the common rollback contract. Restore personal profile selection.

## 10. Story `MIG-MODULE-repos`: Transfer repository declarations

### Metadata — `MIG-MODULE-repos`

- Module key: `repos`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/repos.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-repos.md`
- Dependencies: `MIG-MODULE-packages`
- Current owner: `mise`
- New owner: `mise`
- Source: `.config/mise/conf.d/bootstrap-repos.toml`
- Target: repository resources
- Mode: `[bootstrap.repos]`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-repos`

Rename the repository declaration to `module.repos.toml`. Preserve repository
paths, URLs, refs, update behavior, and dirty-repository protection.

### Steps — `MIG-MODULE-repos`

1. Read the repository inventory.
2. Record repository paths and dirty state.
3. Rename the declaration.
4. Do not remove repositories during this story.
5. Run the `repos` module-focused test.

### Acceptance checks — `MIG-MODULE-repos`

- Every repository remains declared.
- Dirty repositories are not overwritten.

### Rollback and mitigation — `MIG-MODULE-repos`

Use the common rollback contract. Do not delete repository checkouts.

## 11. Story `MIG-MODULE-tools`: Transfer tool declarations

### Metadata — `MIG-MODULE-tools`

- Module key: `tools`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/tools.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-tools.md`
- Dependencies: `MIG-MODULE-packages`
- Current owner: `mise`
- New owner: `mise`
- Source: `.config/mise/conf.d/tools.toml`
- Target: tool installations
- Mode: `[tools]`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-tools`

Rename the tool declaration to `module.tools.toml`. Preserve versions,
postinstall hooks, lockfile behavior, and package-manager separation.

### Steps — `MIG-MODULE-tools`

1. Read the exhaustive tool inventory.
2. Record tool versions and postinstall hooks.
3. Rename the declaration.
4. Keep application configuration outside the tools module.
5. Run the `tools` module-focused test.

### Acceptance checks — `MIG-MODULE-tools`

- Every tool remains declared.
- Postinstall hooks remain attached to the same tools.

### Rollback and mitigation — `MIG-MODULE-tools`

Use the common rollback contract. Do not prune tools.

## 12. Story `MIG-MODULE-bat`: Transfer the bat module

### Metadata — `MIG-MODULE-bat`

- Module key: `bat`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/bat.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-bat.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/bat`
- Target: `~/.config/bat`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-bat`

Move `bat` configuration and the Catppuccin theme under `~/dev/personal/dot/home/.config/bat`.
Keep the source download in `scripts/zsh.zsh` and add the only bat cache hook
to this module.

### Steps — `MIG-MODULE-bat`

1. Read the inventory and target manifest.
2. Copy only approved source files.
3. Update the theme download destination.
4. Apply the ownership transition.
5. Run the `bat` module-focused test and `bat cache --build` check.

### Acceptance checks — `MIG-MODULE-bat`

- The target uses relative `symlink-each` links.
- The cache hook exists only in this module.
- Theme downloads write to the tracked source.

### Rollback and mitigation — `MIG-MODULE-bat`

Use the common rollback contract.

## 13. Story `MIG-MODULE-btop`: Transfer the btop module

### Metadata — `MIG-MODULE-btop`

- Module key: `btop`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/btop.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-btop.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/btop`
- Target: `~/.config/btop`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-btop`

Move `btop` configuration and theme under `~/dev/personal/dot/home/.config/btop`. Keep the theme
download pointed at the tracked source.

### Steps — `MIG-MODULE-btop`

1. Read the inventory and target manifest.
2. Copy only approved source files.
3. Update the theme download destination.
4. Apply the ownership transition.
5. Run the `btop` module-focused test.

### Acceptance checks — `MIG-MODULE-btop`

- The target uses relative `symlink-each` links.
- The theme download writes to the tracked source.

### Rollback and mitigation — `MIG-MODULE-btop`

Use the common rollback contract.

## 14. Story `MIG-MODULE-delta`: Transfer the delta module

### Metadata — `MIG-MODULE-delta`

- Module key: `delta`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/delta.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-delta.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/delta`
- Target: `~/.config/delta`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-delta`

Move the delta theme under `~/dev/personal/dot/home/.config/delta`. Keep the download source
visible to review and preserve Git integration.

### Steps — `MIG-MODULE-delta`

1. Read the inventory and target manifest.
2. Copy the approved theme source.
3. Update the theme download destination.
4. Apply the ownership transition.
5. Run the `delta` module-focused test.

### Acceptance checks — `MIG-MODULE-delta`

- The target uses a relative link.
- The theme download writes to the tracked source.

### Rollback and mitigation — `MIG-MODULE-delta`

Use the common rollback contract.

## 15. Story `MIG-MODULE-zsh`: Transfer the Zsh module

### Metadata — `MIG-MODULE-zsh`

- Module key: `zsh`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/zsh.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-zsh.md`
- Dependencies: `MIG-MODULE-bat`, `MIG-MODULE-btop`, `MIG-MODULE-delta`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/zsh`
- Target: `~/.config/zsh`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-zsh`

Move tracked Zsh source files under `~/dev/personal/dot/home/.config/zsh`. Move every inventoried
history and completion runtime file into the detached target before removing
the parent link. Do not copy sensitive files without erasing and checking the
old path.

### Steps — `MIG-MODULE-zsh`

1. Read the exhaustive Zsh runtime inventory.
2. Save source and target manifests, including ignored files.
3. Copy only approved tracked source files.
4. Add narrow Stow exclusions for runtime files.
5. Detach the confirmed parent Stow link.
6. Move every protected runtime file to its approved runtime destination.
7. Apply the `symlink-each` declaration.
8. Preserve `ZDOTDIR`, plugin paths, and shell startup behavior.
9. Run the `zsh` module-focused test and a new shell smoke test.

### Acceptance checks — `MIG-MODULE-zsh`

- Every protected runtime file exists at its runtime destination.
- No protected runtime file remains under the repository source.
- The new shell starts successfully.
- `ZDOTDIR` resolves to the deployed target.

### Rollback and mitigation — `MIG-MODULE-zsh`

Use the common rollback contract. Restore protected runtime files before the old source and Stow link.

## 16. Story `MIG-MODULE-fd`: Transfer the fd module

### Metadata — `MIG-MODULE-fd`

- Module key: `fd`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/fd.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-fd.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/fd`
- Target: `~/.config/fd`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-fd`

Move the `fd` ignore file under `~/dev/personal/dot/home/.config/fd` without adding unrelated
configuration.

### Steps — `MIG-MODULE-fd`

1. Read the inventory and target manifest.
2. Copy the approved source.
3. Apply the ownership transition.
4. Run the `fd` module-focused test.

### Acceptance checks — `MIG-MODULE-fd`

- The target has one relative link.
- No unrelated files are declared.

### Rollback and mitigation — `MIG-MODULE-fd`

Use the common rollback contract.

## 17. Story `MIG-MODULE-fzf`: Transfer the fzf module

### Metadata — `MIG-MODULE-fzf`

- Module key: `fzf`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/fzf.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-fzf.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/fzf`
- Target: `~/.config/fzf`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-fzf`

Move `fzf.conf` under `~/dev/personal/dot/home/.config/fzf` and preserve
`FZF_DEFAULT_OPTS_FILE` behavior.

### Steps — `MIG-MODULE-fzf`

1. Read the inventory and target manifest.
2. Copy the approved source.
3. Apply the ownership transition.
4. Run the `fzf` module-focused test and shell reference check.

### Acceptance checks — `MIG-MODULE-fzf`

- `FZF_DEFAULT_OPTS_FILE` resolves to the deployed file.
- The target has one relative link.

### Rollback and mitigation — `MIG-MODULE-fzf`

Use the common rollback contract.

## 18. Story `MIG-MODULE-lazygit`: Transfer the lazygit module

### Metadata — `MIG-MODULE-lazygit`

- Module key: `lazygit`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/lazygit.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-lazygit.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/lazygit`
- Target: `~/.config/lazygit`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-lazygit`

Move the lazygit configuration and theme under `~/dev/personal/dot/home/.config/lazygit`.
Preserve `LG_CONFIG_FILE` behavior.

### Steps — `MIG-MODULE-lazygit`

1. Read the inventory and target manifest.
2. Copy the approved source files.
3. Apply the ownership transition.
4. Run the `lazygit` module-focused test and shell reference check.

### Acceptance checks — `MIG-MODULE-lazygit`

- Both files have relative links.
- `LG_CONFIG_FILE` resolves to the deployed configuration.

### Rollback and mitigation — `MIG-MODULE-lazygit`

Use the common rollback contract.

## 19. Story `MIG-MODULE-ripgrep`: Transfer the ripgrep module

### Metadata — `MIG-MODULE-ripgrep`

- Module key: `ripgrep`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/ripgrep.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-ripgrep.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/ripgrep`
- Target: `~/.config/ripgrep`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-ripgrep`

Move `.ripgreprc` under `~/dev/personal/dot/home/.config/ripgrep` and preserve
`RIPGREP_CONFIG_PATH`.

### Steps — `MIG-MODULE-ripgrep`

1. Read the inventory and target manifest.
2. Copy the approved source.
3. Apply the ownership transition.
4. Run the `ripgrep` module-focused test and environment reference check.

### Acceptance checks — `MIG-MODULE-ripgrep`

- `RIPGREP_CONFIG_PATH` resolves to the deployed file.
- The target has one relative link.

### Rollback and mitigation — `MIG-MODULE-ripgrep`

Use the common rollback contract.

## 20. Story `MIG-MODULE-tmux`: Transfer the tmux module

### Metadata — `MIG-MODULE-tmux`

- Module key: `tmux`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/tmux.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-tmux.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/tmux`
- Target: `~/.config/tmux`
- Mode: `symlink-each`
- Risk: `low`
- Status: `blocked`

### Description — `MIG-MODULE-tmux`

Move `tmux.conf` under `~/dev/personal/dot/home/.config/tmux` and add a configuration parse
smoke test.

### Steps — `MIG-MODULE-tmux`

1. Read the inventory and target manifest.
2. Copy the approved source.
3. Apply the ownership transition.
4. Run the tmux parse smoke test and `tmux` module-focused test.

### Acceptance checks — `MIG-MODULE-tmux`

- The target has one relative link.
- The configuration parse smoke test passes.

### Rollback and mitigation — `MIG-MODULE-tmux`

Use the common rollback contract.

## 21. Story `MIG-MODULE-ghostty`: Transfer the Ghostty module

### Metadata — `MIG-MODULE-ghostty`

- Module key: `ghostty`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/ghostty.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-ghostty.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/ghostty`
- Target: `~/.config/ghostty`
- Mode: `symlink-each`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-ghostty`

Move Ghostty configuration and shaders under `~/dev/personal/dot/home/.config/ghostty`. Keep
shader paths.

### Steps — `MIG-MODULE-ghostty`

1. Read the inventory and target-only disposition.
2. Copy approved configuration and shader files.
3. Apply the ownership transition.
4. Run the `ghostty` module-focused test and source smoke checks.

### Acceptance checks — `MIG-MODULE-ghostty`

- Shader references resolve.

### Rollback and mitigation — `MIG-MODULE-ghostty`

Use the common rollback contract.

## 22. Story `MIG-MODULE-git`: Transfer the Git module

### Metadata — `MIG-MODULE-git`

- Module key: `git`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/git.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-git.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/git`
- Target: `~/.config/git`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-git`

Move Git configuration and the global ignore file under `~/dev/personal/dot/home/.config/git`.
Preserve external includes, signing commands, and local-file ignore rules.

### Steps — `MIG-MODULE-git`

1. Read the inventory and target manifest.
2. Inspect external includes and signing paths.
3. Copy approved source files.
4. Apply the ownership transition.
5. Run Git include, ignore, and signing-path checks.

### Acceptance checks — `MIG-MODULE-git`

- External includes resolve.
- The global Git ignore file remains deployed.
- Local variants remain ignored.

### Rollback and mitigation — `MIG-MODULE-git`

Use the common rollback contract.

## 23. Story `MIG-MODULE-wezterm`: Transfer the WezTerm module

### Metadata — `MIG-MODULE-wezterm`

- Module key: `wezterm`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/wezterm.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-wezterm.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/wezterm`
- Target: `~/.config/wezterm`
- Mode: `symlink-each`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-wezterm`

Move WezTerm configuration and shell hooks under `~/dev/personal/dot/home/.config/wezterm`.
Record an explicit disposition for repository-only instruction files and
research backups that the old parent symlink exposes.

### Steps — `MIG-MODULE-wezterm`

1. Read the exhaustive target-content inventory.
2. Preserve or remove every target-only entry according to its disposition.
3. Copy approved configuration and shell hook files.
4. Apply the ownership transition.
5. Run shell syntax checks and the available WezTerm smoke test.

### Acceptance checks — `MIG-MODULE-wezterm`

- The target-only disposition matches the inventory.
- Shell completion and integration files resolve.
- Research backups do not enter `~/dev/personal/dot/home/`.

### Rollback and mitigation — `MIG-MODULE-wezterm`

Use the common rollback contract. Restore preserved target-only files.

## 24. Story `MIG-MODULE-yazi`: Transfer the Yazi module

### Metadata — `MIG-MODULE-yazi`

- Module key: `yazi`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/yazi.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-yazi.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/yazi`
- Target: `~/.config/yazi`
- Mode: `symlink-each`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-yazi`

Move tracked Yazi flavors, plugins, and configuration under `~/dev/personal/dot/home/.config/yazi`.
Preserve dependency pins and exclude untracked runtime state.

### Steps — `MIG-MODULE-yazi`

1. Read the exhaustive tracked and ignored inventory.
2. Copy only approved tracked files.
3. Apply the ownership transition.
4. Check flavor, plugin, and package references.
5. Run the `yazi` module-focused test.

### Acceptance checks — `MIG-MODULE-yazi`

- Every tracked source path has one relative link.
- Untracked runtime state remains outside `~/dev/personal/dot/home/`.
- Dependency pins remain unchanged.

### Rollback and mitigation — `MIG-MODULE-yazi`

Use the common rollback contract.

## 25. Story `MIG-MODULE-1password`: Transfer the 1Password module

### Metadata — `MIG-MODULE-1password`

- Module key: `1password`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/1password.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-1password.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/1Password`
- Target: `~/.config/1Password`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-1password`

Move only the approved SSH agent configuration. Keep vault references. Do not
move private keys or application runtime state.

### Steps — `MIG-MODULE-1password`

1. Read the inventory and secret classification.
2. Copy only the approved configuration.
3. Apply the ownership transition.
4. Run the SSH agent configuration check.

### Acceptance checks — `MIG-MODULE-1password`

- No private key enters `~/dev/personal/dot/home/`.
- Vault references remain valid.

### Rollback and mitigation — `MIG-MODULE-1password`

Use the common rollback contract. Do not restore private keys from the repository.

## 26. Story `MIG-MODULE-betterdisplay`: Transfer the BetterDisplay module

### Metadata — `MIG-MODULE-betterdisplay`

- Module key: `betterdisplay`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/betterdisplay.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-betterdisplay.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow and script
- New owner: `mise` plus script
- Source: `.config/BetterDisplay`
- Target: `~/.config/BetterDisplay`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-betterdisplay`

Move the plist source under `~/dev/personal/dot/home/.config/BetterDisplay`. Apply the README and
backup dispositions recorded in the approved inventory. Update the export
script so it writes to the source and never replaces a deployed symlink.

### Steps — `MIG-MODULE-betterdisplay`

1. Read the inventory and target-only manifest.
2. Copy the approved plist and README disposition.
3. Update `scripts/betterdisplay.zsh`.
4. Apply the ownership transition.
5. Run import, export, symlink-preservation, and syntax checks.

### Acceptance checks — `MIG-MODULE-betterdisplay`

- Export writes to the approved source path.
- Import reads the approved source.
- Export does not replace the deployed link.
- Display identifiers remain classified.
- The BetterDisplay test passes.

### Rollback and mitigation — `MIG-MODULE-betterdisplay`

Use the common rollback contract. Restore the old script and preserved backup files.

## 27. Story `MIG-MODULE-hammerspoon`: Transfer the Hammerspoon module

### Metadata — `MIG-MODULE-hammerspoon`

- Module key: `hammerspoon`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/hammerspoon.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-hammerspoon.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/hammerspoon`
- Target: `~/.config/hammerspoon`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-hammerspoon`

Move eligible tracked Lua and `Spoons/` files under `~/dev/personal/dot/home/.config/hammerspoon`.
Record the disposition of `.luarc.json` and all target-only runtime files.

### Steps — `MIG-MODULE-hammerspoon`

1. Read the exhaustive Lua and target-content inventory.
2. Copy only eligible tracked files.
3. Apply the ownership transition.
4. Run Lua syntax checks and the Hammerspoon application check when available.

### Acceptance checks — `MIG-MODULE-hammerspoon`

- The eligible manifest excludes repository-only files.
- `Spoons/` remains complete.
- Lua syntax passes.
- The target-only disposition matches the inventory.

### Rollback and mitigation — `MIG-MODULE-hammerspoon`

Use the common rollback contract.

## 28. Story `MIG-MODULE-harper`: Transfer the Harper module

### Metadata — `MIG-MODULE-harper`

- Module key: `harper`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/harper.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-harper.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/harper`
- Target: `~/.config/harper`
- Mode: `symlink-each`
- Risk: `medium`
- Status: `blocked`

### Description — `MIG-MODULE-harper`

Move the personal Harper dictionary under `~/dev/personal/dot/home/.config/harper`. Treat its
content as personal configuration and do not print it during validation.

### Steps — `MIG-MODULE-harper`

1. Read the inventory and data classification.
2. Copy the approved dictionary.
3. Apply the ownership transition.
4. Run metadata and target checks.

### Acceptance checks — `MIG-MODULE-harper`

- The dictionary has one owner.
- Its contents are not printed.

### Rollback and mitigation — `MIG-MODULE-harper`

Use the common rollback contract.

## 29. Story `MIG-MODULE-nvim`: Transfer the Neovim module

### Metadata — `MIG-MODULE-nvim`

- Module key: `nvim`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/nvim.md`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-MODULE-nvim.md`
- Dependencies: `MIG-MODULE-mise`
- Current owner: GNU Stow
- New owner: `mise`
- Source: `.config/nvim`
- Target: `~/.config/nvim`
- Mode: `symlink-each`
- Risk: `high`
- Status: `blocked`

### Description — `MIG-MODULE-nvim`

Move the tracked Neovim files under `~/dev/personal/dot/home/.config/nvim`. Preserve direct edits
and the `.gitignore` boundary for generated runtime files.

### Steps — `MIG-MODULE-nvim`

1. Read the inventory and `.gitignore` boundary.
2. Copy the tracked source files with modes preserved.
3. Apply per-file relative `symlink-each` links.
4. Run `nvim --headless '+qa'`.
5. Run the `nvim` module-focused test.

### Acceptance checks — `MIG-MODULE-nvim`

- `~/.config/nvim` is a physical directory with per-file relative links.
- Generated runtime files remain outside the managed source set.
- Direct edits reach the repository source.
- Ignored generated files remain untracked.
- The Neovim smoke test passes.

### Rollback and mitigation — `MIG-MODULE-nvim`

Use the common rollback contract. Restore the directory target.

## 30. Story `MIG-90`: Activate profiles and complete final validation

### Metadata — `MIG-90`

- Scope: profile selection, final checks, documentation, and closeout
- Approval: `required`
- Approval record: `.agents/projects/stow-to-mise-migration/research/approvals/MIG-90.md`
- Dependencies: every `MIG-MODULE-*` story
- Status: `blocked`

### Description — `MIG-90`

Activate the selected profiles, run final validation, update the migration
documentation, and record remaining exceptions after every module story passes.

### Steps — `MIG-90`

1. Validate every inventory and approval record.
2. Run every focused module test.
3. Run `mise run check`.
4. Run `mise bootstrap status --json`.
5. Run target-scoped `mise dot status` and dry runs for every migrated target.
6. Run `stow -nvR .`.
7. Update `README.md` with the final ownership model and intentional
   repository-only boundaries.
8. Update `tests/scripts/README.md` with current declarations and tests.
9. Read the approved full-flow integration-test record.
10. Run `./scripts/init.zsh --mise`.
11. Record completed stories, baseline differences, residual exclusions, and
    deferred smoke tests.
12. Keep all migration changes uncommitted until the final approval record is
    complete and every acceptance check passes.

### Acceptance checks — `MIG-90`

- Every module story is approved and complete.
- No target has dual ownership.
- No protected runtime file is in `~/dev/personal/dot/home/`.
- No unexpected target or source difference remains.
- Focused tests and aggregate checks pass.
- The final full-flow test passes.
- The project tracker records every remaining exception.

### Rollback and mitigation — `MIG-90`

Stop at the first failed module. Restore that module from its recorded
inventory and baseline. Do not continue with later module stories.

## Execution handoff

- Consume only this plan path:
  `~/dev/personal/dot/.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`.
- Satisfy the execution entry criteria before the first story enters `todo`.
- Use the module registry for coverage and dependency identifiers.
- Use the story order in this roadmap as the only execution order.
- Mark only the next incomplete story in this roadmap as `todo`.
- Apply the shared story contract and each story's module-specific rules.
- Stop on missing inventory fields, unknown sensitive paths, unexpected target
  content, invalid legacy cleanup output, or duplicate ownership.
