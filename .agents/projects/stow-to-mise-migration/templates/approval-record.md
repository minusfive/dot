# Migration Approval Record

## Story

- Story key: `MIG-<id>`
- Module key: `<module|shared>`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/<module>.md`
- Approval state: `pending` or `approved`
- Approver: `<name or pending>`
- Approved at: `<timestamp or pending>`
- Approved scope: `<exact boundary or pending>`
- Approval evidence: `<reference or pending>`

## Apply gate

- Baseline record: `<path or pending>`
- Dry-run record: `<path or pending>`
- Focused test: `<path or pending>`
- Rollback record: `<path or pending>`
- Final decision: `<pending|approved for execution>`

## Notes

`pending` means that no mutation is authorized. `approved` authorizes only the
exact scope recorded in this file.
