## `integer`. Story `MIG-<id>`: `<action>` `<module>`

### Metadata

- Module key: `<module>`
- Inventory: `.agents/projects/stow-to-mise-migration/research/inventories/<module>.md`
- Approval: `required`
- Dependencies: `<story keys or none>`
- Current owner: `<owner>`
- New owner: `<owner>`
- Target: `<path or none>`
- Mode: `<mode>`
- Risk: `<low|medium|high|critical>`
- Status: `<blocked|todo|research|implement|validate|critique|done>`

### Description

`<One concise paragraph that states the current boundary, the intended
ownership transition, and the behavior that must remain unchanged.>`

### Steps

1. Read the module inventory.
2. Record the current target and source manifests.
3. Apply the shared ownership transition procedure.
4. Run the module-specific preparation steps from the inventory.
5. Run the one focused test named for this module and the target smoke checks.
6. Record the approval, result, baseline difference, and rollback state.

### Acceptance checks

- The inventory is complete and uses the common format.
- The source set matches the inventory.
- The target has one owner.
- The story names exactly one focused test path for this module.
- The focused test covers only this module.
- Runtime and sensitive files remain at their approved destinations.
- The focused test passes.
- The target smoke test passes or the inventory records its approved deferral.
- The rollback check passes.

### Rollback and mitigation

- Preserve the recorded source and target manifests.
- Unapply only this module after a dry run.
- Restore the previous owner and preserved local files.
- Stop when the target contains unmanaged content or an unexpected owner.
