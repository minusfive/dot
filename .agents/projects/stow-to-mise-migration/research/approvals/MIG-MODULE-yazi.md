# Migration Approval Record

## Story

- Story key: `MIG-MODULE-yazi`
- Module key: `yazi`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/yazi.md`
- Approval state: `pending`
- Approver: `pending`
- Approved at: `pending`
- Approved scope: All source paths, target paths, exclusions, runtime dispositions, and rollback boundaries recorded in `.agents/projects/stow-to-mise-migration/research/inventories/yazi.md`; target root `~/.config/yazi`; mise mode `symlink-each`; no other repository or user paths. (scope recorded; story authorization remains pending)
- Approval evidence: `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`; `.agents/projects/stow-to-mise-migration/research/baseline-record-20261011T164747-0400.md`

## Apply gate

- Baseline record: `.agents/projects/stow-to-mise-migration/research/baseline-record-20261011T164747-0400.md`
- Dry-run record: `.agents/projects/stow-to-mise-migration/tmp/baselines/20261011T164747-0400/commands/mise-bootstrap-dotfiles-apply-dry-run.txt`
- Focused test: `tests/scripts/test_mise_bootstrap_yazi.zsh`
- Rollback record: `.agents/projects/stow-to-mise-migration/research/inventories/yazi.md#rollback`
- Final decision: `pending`

## Notes

The exact scope is recorded for review. No mutation is authorized while this
record is pending.
