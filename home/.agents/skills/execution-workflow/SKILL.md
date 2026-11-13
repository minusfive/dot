---
name: execution-workflow
description: Execute an accepted story plan through dependency gates, lifecycle transitions, acceptance checks, and story-level drift recovery. Use when implementing an existing multi-story plan artifact.
---

# Execution Workflow

Use this skill after `planning` produces an accepted plan artifact.

Use `workflow-policy` for assignment boundaries, isolation, budgets, checkpoints, and recovery. Use `review-delivery` for candidate review, findings, rebases, pull requests, and delivery.

This skill owns story lifecycle, dependency gates, acceptance, and story-level drift transitions.

## Start conditions

Consume the exact accepted plan path in the planning handoff. Do not infer a default path. If the path is missing or ambiguous, block execution and request the exact path. Do not rewrite accepted story specifications during execution.

Require current-turn authorization before any story mutation. Freeze the affected story when authorization expires.

Validate every story before work starts. Require a stable story key, dependencies, numbered steps, acceptance checks, and rollback or mitigation notes. Use the plan's accepted version or amendment identifier.

## Story lifecycle

Use this lifecycle for every story:

`blocked -> todo -> research -> implement -> validate -> critique -> done`

Track the story state, blocker reason, unblock condition, failed critique-cycle count, and evidence. Use `blocked` only when a blocker and unblock condition are recorded. Do not add another lifecycle or a parallel story state machine.

Freeze a story by recording its current state and moving it to `blocked` with the blocker and unblock condition.

Move a story from `todo` to `research` only when its hard dependencies are ready. Move it to `implement` after the research and ownership checks pass. Move it to `validate` after the implementation matches the accepted story. Move it to `critique` after focused validation and acceptance evidence are complete. Keep the story in `critique` while delivery evidence is incomplete. Move it to `done` only after `review-delivery` records `delivery complete` and root authorization permits issue closure.

Use these status terms precisely:

- `implementation complete` means that accepted implementation evidence exists. It does not close the issue.
- `validation complete` means that required validation evidence passes. It does not close the issue.
- `delivery complete` means that `review-delivery` records a linked pull request, completed review, and manual-merge handoff evidence. It does not close the issue.
- `story/issue done` means that `execution-workflow` has the required delivery evidence and explicit current-turn root authorization to close the issue.

Keep the issue open and move its Project card through every configured lane as the story advances. Do not move the card to `Done` during implementation, validation, critique, review, or manual-merge handoff. Do not close the issue from implementation complete, validation complete, critique success, pull request approval, or delivery complete alone. Require `review-delivery` evidence for every linked candidate:

- a linked pull request;
- delivery evidence;
- a completed review; and
- a manual-merge handoff.

Require explicit current-turn root authorization before closing any issue. Then record `story/issue done` and move the Project card to `Done`.

After `workflow-policy` completes the canonical `freeze -> report -> escalate -> stop` sequence, planning records either a plan-preserving recovery decision or an accepted recovery amendment. Resume the blocked story at `research` only after that planning decision. Represent this as the recovery edge `blocked -> research` in the same lifecycle. Do not require an amendment only when all required plan fields are present, consistent, and actionable, and the accepted plan, acceptance, scope, ownership, dependencies, security, feasibility, and delivery boundaries remain valid and unchanged. Require an accepted amendment with a new plan version when any required plan field is missing, inconsistent, or non-actionable, or when any one of those boundaries changes.

## Dependency gates

Build the ready queue from the plan's dependency graph. Keep each hard dependency in topological order. Run independent chains concurrently. Gate only the downstream story that names a pending integration checkpoint. Keep unrelated stories running.

Classify each dependency as one of:

- `hard dependency`;
- `shared mutable state`;
- `rebase/delivery dependency`;
- `optional synchronization`.

Use `workflow-policy` for the ready queue, checkpoint ledger, shared-write serialization, and explicit handoffs. Do not turn optional synchronization into a global barrier.

When a dependency becomes ready, name the result, notify the dependent lane, apply the required handoff, validate it, and update the story evidence.

## Story tracking

If a story uses an issue or Project card, mirror every lifecycle transition, blocker, dependency, and acceptance result. Use the repository's configured lanes for `Blocked`, `Todo`, `Research`, `Implement`, `Validate`, `Critique`, and `Done`. Use `review-delivery` for the flexible mapping between the Project/issue graph and pull request candidates. Reopen a closed story when it moves backward and record the reason and unblock condition. Do not move a story to `Done` from approval alone or without the delivery gate above.

## Acceptance and critique

Run every story acceptance check from the accepted plan. Preserve command results and artifact references. Include focused checks and the story's end-to-end integration checkpoint. Keep behavior-coupled documentation and instruction updates in the story that changes the behavior.

Apply the canonical critique gate before `critique -> done`. When critique fails, move the story to `research`, record the findings and next actions, and increment its failed critique-cycle count. After five failed critique cycles, move the story to `blocked` with an explicit blocker and unblock condition.

Use `review-delivery` for independent candidate critique and pull request review. Use `planning` for plan amendment critique and acceptance. Do not duplicate review or delivery mechanics here.

## Story drift

If execution finds missing, inconsistent, or non-actionable plan fields, block the affected story immediately. Preserve its evidence and failed critique-cycle count. Keep dependent stories blocked when they require the affected story. If a worker is active, freeze the story before drift recovery and follow `workflow-policy`. After `workflow-policy` completes the canonical `freeze -> report -> escalate -> stop` sequence, use `planning` to decide whether the accepted plan remains viable. Plan-preserving recovery is allowed only when all required plan fields are present, consistent, and actionable, and acceptance, scope, ownership, dependencies, security, feasibility, and delivery boundaries remain valid and unchanged. If any required plan field is missing, inconsistent, or non-actionable, the plan is non-viable and `planning` must create, critique, and accept a targeted amendment with a new plan version before execution resumes. If any one of those boundaries changes, use `planning` for a targeted amendment, including its critique and acceptance, with a new plan version. Execution consumes the exact accepted amendment path and version, then resumes the story at `research`. Assign remaining work to a new worker after recovery.

If I am unavailable for a required decision, preserve evidence and freeze the affected story. Do not change the plan, ownership, dependencies, or authorization while the decision is pending.

## Output

When asked for an execution workflow, return:

1. Story states and failed critique-cycle counts.
2. The exact plan artifact path and accepted version.
3. The dependency-aware ready queue and checkpoint references.
4. Active lanes and integration boundaries.
5. Blockers and drift findings with required planning amendments.
6. Per-story acceptance and critique status.

Keep commit, push, pull request, and merge authority with `review-delivery`.
