---
name: execution-workflow
description: Execute deterministic story plans through dependency-aware workflow state transitions, PR/card lifecycle discipline, and critique-gated completion. Use when implementing an existing multi-story plan artifact.
---

# Execution Workflow

Use this skill after planning is complete and you need to execute an existing plan through issues, board cards, PRs, and merges.

Use the `orchestrator` agent as the primary coordinator. Follow `task-orchestration` for delegation and runtime isolation. Load `pr-orchestration` before multi-issue GitHub delivery.

This skill owns story lifecycle and dependency gates.

Delegate story, issue, project-card, sub-issue, and review-state mutations to bounded workers. Keep final state decisions, handoffs, integration, and completion with the `orchestrator`.

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
9. Keep each dependency chain in topological order. Run independent chains concurrently.

## Execution topology

1. Reuse the coordination worker to build execution lanes from plan-provided dependencies and concurrency boundaries.
   - Have the worker classify each dependency as `hard dependency`, `shared mutable state`, `rebase/delivery dependency`, or `optional synchronization`.
   - Have the worker maintain the dependency-aware ready queue and checkpoint ledger required by `task-orchestration`.
   - Have the worker report every story whose hard dependencies are ready.
   - Assign approved ready stories concurrently.
   - Follow `task-orchestration` for worktree isolation and shared-write serialization.
   - Use a `serialized shared-mutation lane` only for an explicitly recorded shared mutation or rebase/delivery boundary. Keep every other repository-changing scope in its own worktree.
2. Preserve the plan's vertical integration checkpoints:
   - Gate only the downstream lane that names the checkpoint as a dependency.
   - Keep unrelated lanes running while that checkpoint is pending.
3. Annotate each executing story as one of:
   - Sequential (critical path)
   - Parallelizable lane
   - Merged-with sibling (single PR covering multiple stories)
4. When a dependency becomes ready, make an explicit handoff. Name the result, notify the dependent lane, rebase or apply the result when required, validate it, and update the ledger.
5. Do not turn the full workflow into a serial queue.

## Kanban lifecycle

1. Track each story as an issue/card using the canonical lifecycle defined above.
2. Use blocked status only with an explicit blocker reason and unblock condition.
3. Keep issue/card status synchronized at each transition.
4. Apply the critique gate at the `critique` state before any transition to `done`.

## GitHub project tracking

1. Before using a GitHub Project, follow the `github-cli` Project authentication preflight.
2. If GitHub Projects are available for the repository, create or use a project as the Kanban board for story execution.
3. Make sure that the project is linked to the repository before you add stories. Link a newly created project immediately after creation.
4. Configure the Kanban view with exactly these lanes: `Blocked`, `Todo`, `Research`, `Implement`, `Validate`, `Critique`, and `Done`.
5. Add each story to the project and map its lifecycle field to those lanes.
6. Move each issue and project card through the lanes at every lifecycle transition.
7. If an issue moves backward from `Done` to any earlier lifecycle lane, reopen it if it is closed, record the reason and unblock condition, and synchronize the issue and project card.
8. If GitHub sub-issues are available, use a parent issue for each story and sub-issues for independently tracked implementation units.
9. Keep parent issues, sub-issues, and project cards synchronized at every lifecycle transition.
10. Keep the accepted plan as the source of truth. Use GitHub issues, sub-issues, and project cards to reflect story state, dependencies, blockers, and acceptance evidence.

## Reconciliation checkpoints

1. Reuse the reconciliation worker for each cycle.
2. Have it update the ready queue and checkpoint ledger for every active lane.
3. Reuse the review-monitoring worker to read current issue and project state with `gh`.
4. Have it poll watched pull requests with `mise run pr:review-watch -- poll`.
5. Have the reconciliation worker report drift and proposed corrections before the affected lane advances.
6. Approve each correction before delegating the required state mutation.
7. Resume every approved ready lane after reconciliation.
8. Treat reconciliation as a global barrier only when the ledger records a hard dependency, shared mutation, rebase, or delivery boundary.

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
3. Dependency-aware ready queue for stories in `todo` and `research`, plus the checkpoint ledger for every active lane.
4. Lane and merge plan for active stories (sequential, parallel, merged).
5. Blockers and drift findings with required planning patches.
6. Per-story acceptance, critique, and merge gate status.
