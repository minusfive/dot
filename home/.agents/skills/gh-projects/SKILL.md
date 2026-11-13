---
name: gh-projects
description: Use when creating, inventorying, reconciling, repairing, retrying, validating, closing, or deleting GitHub Projects, Project items, fields, labels, dependencies, or related gh:project tasks. Use for duplicate detection, kanban convergence, recovery, cleanup authorization, and Project evidence.
---

# GitHub Projects

Use this skill for GitHub Project control-plane work.

## Authority and boundaries

Use `workflow-policy` for current-turn authorization, budgets, checkpoints, freeze, escalation, and recovery state. Use `execution-workflow` for story lifecycle, status terms, issue closure, and Project-card mirroring. Use `github-cli` for GitHub authentication and `gh` command selection. Use `mise-tasks` for task flags, help, usage, and task validation. Keep Project identity, convergence, cleanup safety, and Project evidence in this skill.

## Exact identity preflight (GP-01)

Load the accepted plan before any Project read or mutation. Normalize the target as `host`, `owner`, `repository`, `title`, and `key`. Set `key` to `<owner>/<repository>:<title>` unless the accepted plan defines another exact key. Check the active `gh` host and the `project` scope before a GitHub Project operation. Read all open and closed Projects for the owner. Page both scopes until the provider reports no next page. Use a limit only when the provider proves that it covers the complete inventory. Read repository linkage and the Project node identity for every title candidate. Match `host`, owner login, repository name, title, key, Project node ID, and Project number exactly. Record a comparison digest for the complete preflight snapshot.

Record the inventory state as open and closed scopes, page or cursor coverage, and a complete-inventory result. Treat an open-only read, a bounded read with unknown completeness, or a missing closed scope as an unsafe preflight. Do not mutate or retry from an unsafe preflight.

## Duplicate rejection (GP-02)

If more than one Project matches the complete target identity, stop with `hard_failure`. Do not select a keeper, retry creation, close a candidate, delete a candidate, or mutate children. Report same-title Projects with wrong linkage as wrong identity, not as the target. If exactly one Project matches, reuse its node ID and number. If no Project matches, classify the target as `bootstrap_required` and wait for mutation authorization.

## Inventory and authorization (GP-03, GP-04)

Keep inventory read-only by default. Treat an inventory result as evidence, not as cleanup authorization. Require current-turn authorization and an accepted recovery decision before cleanup or live mutation. Require a separate current-turn retry authorization for every retry after an external mutation. Do not treat a retry count, a task default, or a ledger field as retry authorization. Freeze the lane when authorization expires, identity becomes ambiguous, or required evidence is missing.

Treat retry authorization as a different decision from the original mutation authorization. Record its owner, scope, expiry, and safe evidence path. If the task exposes only a retry count, the retry is not authorized.

## Durable create and retry identity (GP-05)

Persist the plan digest and target identity before a create operation. Persist the client mutation ID, Project node ID, Project number, response timestamp, provider request ID when available, and response digest. Treat a create response without a complete durable identity as `hard_failure`. Before a retry, read the complete open and closed owner inventory again and match the durable identity. If the created Project is present exactly once, reconcile that Project instead of creating another. If the identity is missing, conflicting, or ambiguous, stop and request a recovery decision.

## Fail-closed reads (GP-06)

Treat timeout, API error, unavailable response, malformed response, missing identity, and digest mismatch as `hard_failure`. Never convert a dependency-read error into an empty dependency list. Distinguish an unsupported dependency capability from a successful empty dependency response. Record the operation, error class, and safe response digest in evidence.

## Missing-only reconciliation (GP-07)

Read the selected Project immediately before each mutation group. Require exactly one selected Project with the same node ID and number on every group read. Match children by complete stable identity, not by title or array position. Apply only children that are absent from the fresh read. Stop on duplicate, wrong, missing, or ambiguous child identity. Use mutation groups for Status, items, labels, and dependency edges. Read the selected Project after every mutation group.

## Exact kanban columns (GP-08, GP-09)

Require exactly these seven Status options in this order: `Blocked`, `Todo`, `Research`, `Implement`, `Validate`, `Critique`, `Done`. Reject missing, extra, duplicate, or ambiguously identified options. Read existing option IDs, colors, and descriptions before a replacement update. Preserve IDs for retained options. Send `singleSelectOptions` as typed GraphQL objects through `gh api graphql --input -`. Do not pass the GraphQL input object as a JSON string.

Compare option order as well as option names and identities. A matching set in a different order is not converged. Treat a task result as insufficient when it proves membership and count but does not prove order.

## Default board view (GP-09b)

Before accepting a Project, read the Project root and every available view. Require exactly one canonical default view, or the provider's equivalent default-view marker. Require that view to use `BOARD_LAYOUT`.

Convert the initial or provider-default view to `BOARD_LAYOUT` when it exists. Create the canonical view idempotently only when no default view exists. Read the view identity and layout before every view write. Reject a table-only default, duplicate default views, duplicate view identities, and ambiguous default markers.

After the view mutation, read the Project again. Verify the root Project URL and the canonical view URL. Record the Project node ID, view node ID, default marker, layout, root URL, and view URL in evidence. Preserve no-duplicate-view and read-before-write rules.

## Items, labels, and dependencies (GP-10)

Match an issue item by issue node ID, issue number, and repository name. Add an issue item only when that complete identity is absent. Match a label by exact repository label name and issue association. Create or attach a label only when the exact association is absent. Match a dependency by source issue, target issue, and `blocked_by` kind. Create a dependency edge only when that exact edge is absent. Treat duplicate or unexpected items, labels, or dependency edges as a reconciliation failure.

## Close and delete safety (GP-11)

Prefer the reversible close operation when a Project must be taken out of active use. Reopen a closed Project with the native `--undo` operation when authorized. Use delete only after a fresh inventory, an explicit cleanup authorization, a selected keeper decision, and a recorded rollback limitation. Never delete a Project as an automatic retry or duplicate-resolution step.

## Evidence and redaction (GP-12, GP-13, GP-14)

Write versioned plan, result, comparison, mutation-journal, and digest evidence. Match the current `project-result.v1` schema and validator field names and nested shapes. Include `retry_authorized`, `retry_authorization`, `lane_state`, `secret_status`, `redaction_status`, `second_read_consistency`, and `inventory` in every result. Record target identity, status, comparison digest, mutation authorization, retry authorization, second-read result, missing children, failures, partial Project identities, retry count, and journal entries. Record durable create identity and default-board-view evidence in the mutation journal or comparison evidence. Record exact safe paths and command results. Redact tokens, cookies, authorization headers, signed query values, and raw sensitive response bodies. Use a digest and a redaction marker when a response body is not safe to retain. Do not claim `ready` without a successful final second read that proves exact convergence.

## Stop conditions (GP-15)

Stop before mutation when the target is duplicated, the dependency read fails, the selected identity changes, the retry lacks separate authorization, or evidence cannot prove convergence. Preserve evidence and hand off the blocker to the owning workflow skill. Never claim live success from fixture success.

## References

Read `references/project-recovery.md` for the native command matrix, typed GraphQL input shape, safe mutation template, and close or reopen commands. Read `references/evidence-schema.md` for required evidence fields and redaction rules.

## Executable enforcement and test hooks

Keep runtime enforcement in `home/.config/mise/tasks/gh/project.ts` and `home/.config/mise/tasks/gh/project-validate.ts`. Keep the focused contract in `tests/scripts/test_mise_task_gh_project.zsh`. Add tests for duplicate exact identity, durable create identity, separate retry authorization, fail-closed dependency reads, missing-only child reconciliation, exact seven options and order, default Board view convergence, no duplicate views, read-before-write view mutation, root and view URL verification, item and label convergence, dependency convergence, post-group reads, close-versus-delete authorization, and redaction. Keep fixture tests separate from live tests. Require the result validator to reject missing nested identity, invalid discriminators, duplicate children, invalid dependency references, and inconsistent second reads. Run `zsh tests/scripts/test_mise_task_gh_project.zsh`, `mise run gh:project --help`, `mise tasks info gh:project`, `mise run ai:skills:evals:validate`, `mise run ai:skills:validate-conflicts`, `mise run mise:tasks:validate-conflicts`, `mise run lint-skill-index --base-path home`, and `mise run fix` after application. Do not perform live GitHub mutation in skill evaluation.

Keep the task, plan schema, result schema, and validator aligned with these rules. Treat a fixture pass as insufficient evidence for live behavior. Treat missing cursor coverage, incomplete durable identity, missing retry authorization, unordered Status options, untyped GraphQL input, or missing required result fields as blockers. Do not weaken this skill to match an executable defect.

## Skill evaluation

Evaluate these cases with and without the skill:

1. An open and closed paginated inventory must reject an exact duplicate.
2. A partial create followed by a retry must reuse one durable Project identity.
3. A duplicate exact target must stop before cleanup or mutation.
4. A Project with incomplete or reordered Status options must fail the exact seven-column contract.
5. A Status update must use typed GraphQL input.
6. A dependency API error must not become an empty graph.
7. Result evidence must match the task schema and validator.
8. Inventory must remain read-only, and close must stay safer than delete.
9. A converged Project must prove item, label, dependency, ordered Status, default Board view, and second-read equality.

Run discoverability evaluation with positive, negative, and overlapping `github-cli`, `workflow-policy`, `execution-workflow`, and `mise-tasks` prompts.
