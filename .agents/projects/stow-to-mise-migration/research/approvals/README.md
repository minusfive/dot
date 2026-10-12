# Migration approvals

Create one approval record for each story from
`.agents/projects/stow-to-mise-migration/templates/approval-record.md`.

Use these rules:

- Keep each record `pending` until the user approves that story. The approval
  record is the authorization SSoT; the matching inventory `Approval state`
  must mirror it.
- Name each record with its story key.
- Record the exact inventory, baseline, dry-run, focused test, and rollback
  paths.
- Record one focused test path for each module story. Aggregate checks do not
  replace the module test.
- Record the authenticated GitHub login from `gh api user`, prefixed with `@`,
  as the approver for approved records. Do not record the harness account.
- Do not treat approval for one story as approval for another story.
- Require a separate approval for `MIG-90` before the full-flow apply.
- Keep each story key, module key, and inventory path aligned with the module
  registry; the artifact validator checks these references.
- The roadmap owns lifecycle `Status`. Do not use `Approval state` as a
  substitute for lifecycle status.

Approval records and the baseline summary are durable planning artifacts and
belong in Git. Run-specific command output, source manifests, and complete
target manifests belong under
`.agents/projects/stow-to-mise-migration/tmp/baselines/` and remain ignored.
