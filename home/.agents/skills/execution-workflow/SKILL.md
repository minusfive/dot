---
name: execution-workflow
description: Execute deterministic story plans through dependency-aware workflow state transitions, PR/card lifecycle discipline, and critique-gated completion. Use when implementing an existing multi-story plan artifact.
---

# Execution Workflow

Use this skill after planning is complete and you need to execute an existing plan through issues, board cards, PRs, and merges.

Use the `orchestrator` agent as the primary coordinator. Follow `task-orchestration` for delegation and runtime isolation. Load `pr-orchestration` before multi-issue GitHub delivery.

This skill owns story lifecycle and dependency gates.

## Canonical lifecycle

Use this lifecycle for every story and transition:

`blocked -> todo -> research -> implement -> validate -> critique -> done`

## Workflow contract

1. Treat the plan as the canonical source of truth.
2. Validate that each story block has required machine-parseable fields before execution:
   - Story key
   - Dependencies
   - Numbered implementation steps
   - Acceptance checks
   - Rollback/mitigation notes
3. Resolve and use the exact accepted plan artifact path provided by planning handoff (or an explicit path I provide) before starting execution; do not infer default paths.
4. When I identify GitHub issues as the plan source, treat each issue description as that story's canonical plan.
5. Refine each issue description before implementation when required plan fields are missing, inconsistent, or non-actionable.
6. Follow `pr-orchestration` for independent critique before GitHub issue-plan updates.
7. If no explicit plan artifact or issue-based plan source is available, stop and request one before execution.
8. Do not rewrite accepted story specs during execution; if execution discovers drift, trigger the drift protocol and request a targeted planning update.
9. Keep story execution in topological dependency order.

## Execution topology

1. Build execution lanes from plan-provided dependencies and concurrency boundaries:
   - Parallelize only stories marked as independent by the plan.
   - Follow `task-orchestration` for worktree isolation and shared-write serialization.
2. Preserve the plan's vertical integration checkpoints:
   - Do not start downstream expansion before each checkpoint is end-to-end verifiable.
3. Annotate each executing story as one of:
   - Sequential (critical path)
   - Parallelizable lane
   - Merged-with sibling (single PR covering multiple stories)

## Kanban lifecycle

1. Track each story as an issue/card using the canonical lifecycle defined above.
2. Use blocked status only with an explicit blocker reason and unblock condition.
3. Keep issue/card status synchronized at each transition.
4. Apply the critique gate at the `critique` state before any transition to `done`.

## Critique Gate

1. Follow the canonical critique gate defined in `AGENTS.md`.
2. Apply the gate for every `critique -> done` transition, not only at conversation end.
3. When critique fails, move the story to `research` with documented findings and next-cycle actions.
4. Count each failed critique as one cycle for that story.
5. If a story reaches 5 failed critique cycles without passing, move it to `blocked` with an explicit blocker reason and unblock condition.

## PR and verification discipline

1. Follow `pr-orchestration` for PR boundaries, review cycles, and merge handoff.
2. Follow `pr-guidelines` for authorized pushes and PR metadata updates.
3. Verify story acceptance checks and preserve evidence in the story artifact trail.

## Drift protocol

1. If execution discovers missing, inconsistent, or non-actionable plan fields, move the affected story to blocked immediately.
2. If a delegated worker is active, move the affected story to blocked before drift recovery. Preserve its failed critique-cycle count, then follow the drift recovery sequence in `task-orchestration` before changing plan or ownership.
3. Treat a missing or ambiguous plan artifact path as drift and block execution until the explicit path is available.
4. Use `planning` for targeted plan changes and `pr-orchestration` for critique before GitHub issue-plan updates.
5. After the accepted plan patch lands, move the affected story to `research` and assign the remaining work to a new worker.

## Output shape

When asked to produce an execution workflow, return:

1. Story execution state map using the canonical lifecycle states, plus failed critique cycle count per story.
2. Exact plan artifact path in use for this execution cycle.
3. Dependency-aware next-action queue for stories in `todo` and `research`.
4. Lane and merge plan for active stories (sequential, parallel, merged).
5. Blockers and drift findings with required planning patches.
6. Per-story acceptance, critique, and merge gate status.
