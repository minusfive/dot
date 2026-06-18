---
name: execution-workflow
description: Execute deterministic story plans through dependency-aware workflow state transitions, PR/card lifecycle discipline, and critique-gated completion. Use when implementing an existing multi-story plan artifact.
---

# Execution Workflow

Use this skill after planning is complete and you need to execute an existing plan through issues, board cards, PRs, and merges.

## Workflow contract

1. Treat the plan as the canonical source of truth.
2. Validate that each story block has required machine-parseable fields before execution:
   - Story key
   - Dependencies
   - Numbered implementation steps
   - Acceptance checks
   - Rollback/mitigation notes
3. Resolve and use the exact accepted plan artifact path provided by planning handoff (or an explicit path I provide) before starting execution; do not infer default paths.
4. If no explicit plan artifact path is available, stop and request it before execution.
5. Do not rewrite story specs during execution; if plan fields are missing, inconsistent, or non-actionable, trigger the drift protocol and request a targeted planning update.
6. Keep story execution in topological dependency order.

## Execution topology

1. Build execution lanes from plan-provided dependencies and concurrency boundaries:
   - Parallelize only stories marked as independent by the plan.
   - Serialize shared mutable-state writes (for example, merge order or board-status updates).
2. Preserve the plan's vertical integration checkpoints:
   - Do not start downstream expansion before each checkpoint is end-to-end verifiable.
3. Annotate each executing story as one of:
   - Sequential (critical path)
   - Parallelizable lane
   - Merged-with sibling (single PR covering multiple stories)

## Kanban lifecycle

1. Track each story as an issue/card through a visible status flow (for example: todo -> research -> implement -> critique -> done).
2. Use blocked status only with an explicit blocker reason and unblock condition.
3. Keep issue/card status synchronized at each transition.
4. Apply the critique gate before moving a story to done.

## Critique Gate

1. Follow the canonical critique gate defined in `AGENTS.md`.
2. Apply the gate at each story-to-done transition, not only at conversation end.
3. When critique fails, move the story back to a prior state with documented findings and next-cycle actions.

## PR and verification discipline

1. Keep one PR per story spec, or one PR per approved merged-story spec.
2. Include explicit issue-closing references in the PR body for all covered stories.
3. Verify acceptance checks before merge and preserve evidence in the story artifact trail.

## Drift protocol

1. If execution discovers missing, inconsistent, or non-actionable plan fields, move the affected story to blocked immediately.
2. Record the exact drift details and the minimum plan patch needed to resume execution.
3. Treat a missing or ambiguous plan artifact path as drift and block execution until the explicit path is provided.
4. Do not silently improvise or rewrite the plan during execution; surface drift details to me or the orchestrator and load the `planning` skill to produce a targeted plan patch, then resume from blocked once the patch lands.

## Output shape

When asked to produce an execution workflow, return:

1. Story execution state map (ready, in-progress, blocked, critique, done).
2. Exact plan artifact path in use for this execution cycle.
3. Dependency-aware next-action queue for ready stories.
4. Lane and merge plan for active stories (sequential, parallel, merged).
5. Blockers and drift findings with required planning patches.
6. Per-story acceptance, critique, and merge gate status.
