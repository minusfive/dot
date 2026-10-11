# Migration planning work

This document tracks planning work. It is not an execution story list.

Execution cannot start until every required planning item is complete and the
pending-decisions document has no pending decision.

## Work items

### `PLAN-01`: Complete inventories and planning artifacts

- Status: `complete`
- Evidence:
  - 29 module inventories exist.
  - All inventories use the common template.
  - The artifact validator passes.
  - The prompt render test passes.
- Exit condition: complete.

### `PLAN-02`: Resolve pending migration decisions

- Status: `complete`
- Document: `.agents/projects/stow-to-mise-migration/research/pending-decisions.md`
- Owner: user and planning agent
- Evidence:
  - `DEC-mise-control-plane-transition-mechanism`: the mise control-plane
    story retains the temporary bridge.
  - `DEC-focused-test-surface`: each module story has one focused test path,
    and aggregate checks do not replace the module test.
  - `DEC-tmux-runtime-classification`: the tmux inventory classifies TPM as an
    external, unmanaged runtime dependency and defers plugin-load validation
    until TPM is installed.
  - `DEC-mise-control-plane-source-resolution`: use explicit
    `~/dev/personal/dot/home/...` source paths for declarations loaded from
    `~/.config/mise`; do not set `dotfiles.root`.
- Exit condition: every decision has a recorded resolution and no record has
  status `pending`.

### `PLAN-03`: Complete the pre-execution baseline packet

- Status: `complete`
- Templates:
  - `.agents/projects/stow-to-mise-migration/templates/baseline-record.md`
  - `.agents/projects/stow-to-mise-migration/templates/approval-record.md`
- Scope:
  - record `mise` and Stow versions;
  - record current status and dry runs;
  - save tracked, ignored, and untracked manifests;
  - save complete target manifests; and
  - record pre-existing differences.
- Evidence:
  - Baseline packet:
    `.agents/projects/stow-to-mise-migration/research/baseline-record-20261011T164747-0400.md`.
  - The packet records `mise` `2026.10.5` and GNU Stow `2.4.1`, read-only
    status and dry-run results, source manifests, metadata-only target
    manifests, and pre-existing differences.
  - All mutation stories, including `MIG-90`, have approval records with
    exact inventory-bound scopes. Stories 1 to 5 are approved for execution;
    later stories and `MIG-90` remain pending.
- Exit condition: the baseline record is complete and every mutation story has
  an approval record with an exact recorded scope.

### `PLAN-04`: Approve the execution roadmap

- Status: `complete`
- Scope:
  - review the resolved pending decisions;
  - review the canonical reference hierarchy;
  - confirm that every execution story is deterministic;
  - confirm that dependencies and strict sequential ordering are valid; and
  - confirm that the validator and workflow enforce the next-story gate; and
  - approve the exact roadmap path for execution.
- Evidence:
  - `research/pending-decisions.md` contains the explicit empty state
    `No pending decisions.`.
  - The canonical reference hierarchy, story contracts, dependency graph, and
    strict sequential order are recorded in
    `plans/migration-roadmap-v1.md`.
  - `.agents/projects/stow-to-mise-migration/scripts/validate-artifacts.zsh`
    accepts the approved story prefix and checks the remaining pending
    approval gates.
  - The exact execution handoff path is
    `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`.
    The current request approves stories 1 to 5; the roadmap remains blocked
    until the story 1 source-path and focused-test updates pass.
- Exit condition: the user approves
  `plans/migration-roadmap-v1.md` for execution.

### `PLAN-05`: Resolve mise source-path cutover drift

- Status: `complete`
- Document: `.agents/projects/stow-to-mise-migration/research/pending-decisions.md`
- Scope:
  - determine how relocated mise declarations resolve sources from the
    physical `~/.config/mise` target;
  - update the roadmap, mise inventory, declarations, tests, and rollback
    evidence with the selected portable mechanism; and
  - rerun the artifact validator before resuming story execution.
- Evidence:
  - Story 1 was rolled back after the copied aggregate declarations reported
    their legacy relative source values missing from the new target.
  - The selected replacement uses explicit
    `~/dev/personal/dot/home/...` source paths and does not set `dotfiles.root`.
- Exit condition: `DEC-mise-control-plane-source-resolution` is resolved and
  all affected execution artifacts agree.

### `PLAN-06`: Validate profile and migrated-module selection

- Status: `complete`
- Scope:
  - validate the `conf.d` environment suffix behavior used by
    `module.<name>.toml`;
  - define the initial profile environment lists for `MIG-MODULE-mise`; and
  - prevent an inherited `MISE_ENV` from overriding `DOT_PROFILE`.
- Evidence:
  - The mise environment documentation states that `env_conf_d = true` makes
    the suffix after the first dot select an environment.
  - A temporary mise fixture passed for both profiles:
    `work` loaded `module.mise.toml` and excluded the personal module;
    `personal` loaded `module.mise.toml` and the personal module.
  - The same fixture showed that unscoped legacy fragments remain loaded as
    the transition bridge.
  - A stale `MISE_ENV=work` suppressed the personal module even when
    `DOT_PROFILE=personal`; unsetting `MISE_ENV` restored the personal branch.
  - `zsh tests/scripts/test_mise_config.zsh`,
    `zsh tests/scripts/test_mise_migration_artifacts.zsh`, and
    `validate-artifacts.zsh` passed before this plan update.
- Exit condition: the roadmap and the mise inventory require the initial
  `work`/`personal` plus `mise` lists, later module-list updates, isolated
  profile tests, and explicit `MISE_ENV` cleanup.

## Planning rules

- Do not add planning discovery or decision steps to execution stories.
- Record new questions in `pending-decisions.md`.
- Resolve a question before adding its final instruction to the roadmap.
- Keep execution approvals separate from planning status.
- Do not apply migration changes from this document.
