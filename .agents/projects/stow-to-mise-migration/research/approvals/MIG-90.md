# Migration Approval Record

## Story

- Story key: `MIG-90`
- Module key: `shared`
- Inventory: `none`
- Approval state: `pending`
- Approver: `pending`
- Approved at: `pending`
- Approved scope: Profile selection, final checks, documentation, and closeout from the MIG-90 roadmap story; no module mutation or full-flow apply outside the approved roadmap. (scope recorded; story authorization remains pending)
- Approval evidence: `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md`; `.agents/projects/stow-to-mise-migration/research/baseline-record-20261011T164747-0400.md`

## Apply gate

- Baseline record: `.agents/projects/stow-to-mise-migration/research/baseline-record-20261011T164747-0400.md`
- Dry-run record: `.agents/projects/stow-to-mise-migration/tmp/baselines/20261011T164747-0400/commands/mise-bootstrap-dotfiles-apply-dry-run.txt`; `.agents/projects/stow-to-mise-migration/tmp/baselines/20261011T164747-0400/commands/stow-dry-run.txt`
- Focused test: `mise run check`
- Rollback record: `.agents/projects/stow-to-mise-migration/plans/migration-roadmap-v1.md#rollback-and-mitigation-mig-90`
- Final decision: `pending`

## Notes

The final full-flow apply remains separately approval-gated. No mutation is
authorized while this record is pending.
