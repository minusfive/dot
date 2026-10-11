# Migration approvals

Create one approval record for each story from
`.agents/projects/stow-to-mise-migration/templates/approval-record.md`.

Use these rules:

- Keep every record `pending` until the user approves that story.
- Name each record with its story key.
- Record the exact inventory, baseline, dry-run, focused test, and rollback
  paths.
- Record one focused test path for each module story. Aggregate checks do not
  replace the module test.
- Do not treat approval for one story as approval for another story.
- Require a separate approval for `MIG-90` before the full-flow apply.
- Keep each story key, module key, and inventory path aligned with the module
  registry; the artifact validator checks these references.
