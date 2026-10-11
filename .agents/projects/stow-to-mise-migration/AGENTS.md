# Stow to mise migration project rules

This project is still focused exclusively on refining the plan at
`~/dev/personal/dot/.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`.
Plan execution is not approved. Update this instruction only when I explicitly
ask you to update it. Do not infer execution readiness from completed artifacts,
approvals, or validation.

These rules apply to work under
`.agents/projects/stow-to-mise-migration/`.

## Plan authority

- Use `execution-workflow` for story lifecycle and dependency handling.
- Use this exact execution plan:
  `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`.
- Read `research/planning-work.md` and
  `research/pending-decisions.md` before execution.
- Keep execution blocked while planning work is incomplete or a pending
  decision remains.

Use the plan for story scope, execution order, dependencies, steps, acceptance
checks, and rollback. The story order in the plan is the only execution-order
source. Do not copy sequence groups or positions into other artifacts. Use the
module inventory for observed source paths, target paths, runtime paths,
ownership facts, and path dispositions. Use the approval record for
authorization. Use the baseline record for run-specific state. Use the registry
for module coverage and dependency identifiers. Use templates for structure.
Use other research files as background evidence.

## Settled planning decisions

- Use `symlink-each` for the Neovim boundary. Keep the Neovim roadmap story,
  inventory, and focused test aligned with a physical target directory and
  per-file relative links.
- Keep dependency fields in the roadmap and inventories for human-readable
  story context. Treat `module-registry.toml` as the canonical dependency
  graph, and require the artifact validator to compare all three views.
- Keep `MIG-MODULE-mise` blocked until
  `DEC-mise-control-plane-transition-mechanism` records the approved cutover
  mechanism.

Keep migration artifacts scoped to repository sources and approved migration
targets. Do not add unrelated unmanaged runtime paths as migration inputs,
preservation targets, or blockers.

Maintain the roadmap and every relevant project artifact in the same change.
This includes affected inventories, planning work, pending decisions,
approvals, baseline records, the module registry, and referenced templates.
When a source path, target, mode, dependency, step, acceptance check, rollback
rule, or story order changes, update the plan and every affected artifact
before you finish the plan change. Keep ordering metadata only in the plan.
Run the artifact validator after the paired updates.

When you resolve a decision, record the selected behavior in the roadmap or
affected inventories and record completion in `research/planning-work.md`.
Then remove the resolved record from `research/pending-decisions.md`. Keep
that file limited to unresolved records with a `pending` status. Use `No
pending decisions.` when it has no records. Run the artifact validator after
this cleanup.

Before execution, explore `.config/` for stale or removable files and maintain
`.agents/projects/stow-to-mise-migration/research/config-cleanup-review.md`
with only current removal recommendations. Record evidence, blockers, and
approval requirements for each recommended file. Keep active, deferred,
repository-only, historical, and already-removed paths in their module
inventories or supporting research. Update the roadmap and affected
inventories when a removal recommendation changes execution scope. Do not
remove a candidate without the required approval.
Treat `.DS_Store` as auto-generated macOS metadata. Exclude it from cleanup
candidates, inventory rows, and execution blockers unless active use is proven.

If two references conflict, block the story and record the drift in
`research/pending-decisions.md`. Do not choose a value or rewrite a story
during execution.

## Story execution

- Read the assigned inventory and approval record before each story.
- Apply only the approved story scope.
- Keep approval records pending until the user approves the exact scope.
- Run one mutable ownership transition at a time.
- Run migration work strictly in the story order in the roadmap.
- Complete each story and all its preparation, validation, and apply steps
  before starting the next story.
- Give each module story its own preparation steps and one focused test.
  Do not create shared preparation or tests.
- Mark only the next incomplete roadmap story as `todo`.
- Keep later stories out of `todo` until every preceding story is complete.
- Do not parallelize module inventories, source preparation, declaration
  authoring, validation, ownership transitions, or closeout.
- Keep planning questions and completed planning work in
  `research/planning-work.md`, not in the execution roadmap.

Execution stories must use settled facts. They must not ask an execution agent
to discover, classify, choose, or decide migration behavior.

## Safety

- Keep credentials, databases, WAL files, histories, completion dumps, caches,
  dependencies, and generated output outside `home/`.
- Do not print credential-bearing contents or runtime database contents.
- Preserve local runtime files before removing a parent Stow link.
- Do not copy a sensitive runtime file without erasing and checking the old
  path.
- Do not use `stow --adopt`.
- Use target-scoped `mise dot` commands during cutovers.
- Stop on an unknown sensitive path, unexpected target content, invalid cleanup
  output, or duplicate ownership.

## Validation

Run the artifact validator before execution:

```bash
.agents/projects/stow-to-mise-migration/scripts/validate-artifacts.zsh
```

Run the assigned focused test before aggregate checks. Run the target-scoped
`mise` and Stow dry runs required by the story. Run `mise run check` and
`./scripts/init.zsh --mise` only at the checkpoints defined by the plan.
