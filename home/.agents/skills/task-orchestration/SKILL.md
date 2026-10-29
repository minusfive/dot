---
name: task-orchestration
description: Orchestrate multi-step execution across direct tools and subagents. Use when deciding what to parallelize, what to delegate, which model tier to use, and how to coordinate shared intermediate artifacts.
---

# Task Orchestration

Use this skill when shaping how a task executes: whether to fan out tool calls in parallel, delegate scopes to subagents, pick a model tier per sub-task, or coordinate intermediate artifacts across steps.

## Tools vs Subagents

- Prefer direct tool calls for small, bounded, local operations.
- Delegate a bounded unit when isolated context, specialist capability, or context savings exceed its coordination cost.
- Do not dispatch a subagent for a task the parent can resolve directly in a few tool calls.
- Keep ownership of a long-running workflow with the `orchestrator`. Do not assign the whole workflow to one implementation agent.

## Primary Orchestrator

- Use the `orchestrator` agent as the primary coordinator for delegated, multi-step work.
- Keep task scope, user communication, final decisions, integration, and completion with the `orchestrator`.
- Keep user questions, planning decisions, and the accepted plan with the `orchestrator`.
- Keep critique separate from implementation. Follow `AGENTS.md` for separate current-turn commit and push authorization.
- Follow this skill for delegation boundaries, progress supervision, and recovery.

## Serialized shared-mutation lanes

- Name a `serialized shared-mutation lane` when a lane must mutate a shared worktree or ref.
- Record the applicable `hard dependency`, `shared mutable state`, or `rebase/delivery dependency` before you serialize the mutation. Do not serialize for `optional synchronization`.
- Require explicit current-turn authorization before any mutation, commit, or push in the lane.
- Do not allow another lane to mutate the same worktree or ref while the lane is active. Keep independent feature, fixture, test, and review scopes in isolated worktrees.
- Run all lanes whose dependencies are ready concurrently by default. A serialized shared-mutation lane is not a global barrier.
- Complete the full critique and required validation after the edits and before each authorized commit or push.
- After the authorized commit or shared result, make an explicit handoff to every affected active lane. Rebase each affected branch before delivery and record the handoff in the checkpoint ledger.

## Concurrent Execution

- Identify all independent tasks and lanes before you start. Run them concurrently by default.
- Treat lane parallelization as a fundamental `orchestrator` responsibility for every workflow.
- Continue independent work while unrelated work runs, including review polling, triage, and implementation.
- Classify every reason to wait as one of these dependency types:
  - `hard dependency`: the lane's next action cannot start or continue until a named result, decision, or artifact is ready.
  - `shared mutable state`: lanes can progress independently, but the named mutation must be serialized.
  - `rebase/delivery dependency`: the lane can progress now, but it must receive a handoff or rebase before integration or delivery.
  - `optional synchronization`: the information is useful, but it is never a gate.
- Maintain a dependency-aware ready queue and checkpoint ledger for every active lane. Record the lane, dependency type, prerequisite, current state, next action, handoff or rebase point, and blocker.
- Start every lane whose hard dependencies are ready. Do not wait for optional synchronization, an unrelated critique, or another lane's completion. Treat a shared-worktree or shared-ref update as a gate only when the ledger records it as a hard or rebase/delivery dependency.
- Use checkpoints to update the ledger and resume every ready lane. A checkpoint is not a global barrier unless a recorded dependency requires one.
- Serialize only the exact shared mutation, rebase, integration, or delivery boundary named in the ledger.
- When a dependency becomes ready, make an explicit handoff. Name the result, notify the dependent lane, apply the handoff or rebase, run the required validation, and update the ledger.
- Rebase an affected lane onto the new `main` commit before delivery when the ledger marks that commit as a rebase or delivery dependency.
- Serialize the rebase and delivery operation, then return unrelated lanes to the ready queue.

## Shell Command Supervision

- Monitor active shell commands as well as subagents.
- At startup and after each checkpoint, inspect active shell sessions with the available status and read operations.
- During a long wait, inspect active shell sessions at least every 60 seconds and after each command progress boundary, whichever comes first.
- Before you start a test, build, validator, or delivery command, set a bounded timeout or define an explicit progress checkpoint.
- Allow a command-specific timeout longer than 60 seconds only when the owning worker reports its expected duration and progress boundaries.
- Continue the 60-second inspection cadence during a command-specific timeout.
- Use elapsed time, new output, CPU or process state, and expected duration to distinguish active progress from a stall.
- Before intervention, ask the owning worker for a report.
- If a shell stalls, preserve its output and other evidence before you stop its specific session or process.
- Reassign or recover stalled work without deleting unrelated changes.
- Reconcile shell-session state with lane, issue, and pull request state before you move forward.
- Keep independent lanes concurrent. Shell monitoring is not a global barrier.

## Planning Delegation

- For substantial multi-phase work, assign a bounded planning agent to research constraints and draft end-to-end work units before implementation. Do not draft the plan yourself first.
- Assign a separate planning critic to challenge the draft before implementation starts.
- Keep user questions, decision resolution, and acceptance of the plan with the `orchestrator`.

## Delivery Delegation

- Delegate post-critique delivery work to an independent delivery agent.
- Follow `AGENTS.md`, `commit-guidelines`, `pr-orchestration`, and `pr-guidelines` for authorization, delivery details, and merge authority.

## Subagent Discipline

- Once a subagent owns a scope, do not redo that same scope in the parent.
- Give each assignment a complete, verifiable outcome. Combine related work when coordination cost would exceed its value.
- Slice implementation by end-to-end behavior, not by technical layer or file. Keep related code, tests, and docs in the same unit.
- State the goal, inputs, owned and excluded files, dependencies, allowed actions, expected evidence, acceptance checks, and checkpoint in each assignment.
- Aggregate outputs only at the dependency boundary that consumes them. Keep unrelated lanes running.
- Ask workers for concise progress reports with changed files, completed work, validation evidence, divergence, blockers, and remaining scope.
- At each checkpoint, update the ready queue and ledger. Compare each lane with its estimate, scope, and acceptance checks, then continue every ready lane.
- If an agent cannot deliver, do not take over its assigned work. Use the drift recovery sequence or report a blocker and next action.

## Drift Recovery

- When a worker drifts from its assignment, request a progress report. Tell it to make no further edits and stop after reporting.
- Treat a missed checkpoint, scope growth, or an expired estimate as drift.
- Do not change the plan and send the same worker new instructions.
- Include completed work, changed files, validation evidence, drift, blockers, remaining scope, and branch or worktree state in the report.
- Assign a separate critique worker to assess the report, changes, and validation evidence. Ask whether to keep, discard, or rework the progress, with reasons.
- For the affected lane, wait for the critique before you change the plan, ownership, or dependencies. Keep unrelated lanes in the ready queue.
- Assign a bounded planning worker to update the plan from the critique. Have an independent critic review the patch when the workflow requires it.
- Accept the updated plan, then assign remaining work to new workers with clear boundaries.
- Preserve work that the critique recommends keeping. Discard only isolated, agent-owned changes that the critique finds unusable.
- If the worker cannot report, stop it before critique. Use available evidence, state what is missing, and do not restart it on the same assignment.

## Failure mode

- Example: a direct-main instruction update reserves the `main` worktree as a serialized shared-mutation lane, while an independent fixture lane continues in an isolated worktree.
- Wait only when a later truth or dependency check consumes both results. Hand off the named results at that boundary, and rebase only the lane that depends on the shared mutation.

## Model Selection

- Use the orchestrator's model for every subagent unless I tell you otherwise.

## Runtime isolation

- Use a separate worktree for each execution scope that changes repository files. A serialized shared-mutation lane may reserve one named worktree or ref, but it cannot permit concurrent mutation of that target. Keep all other parallel worktrees independent.
- Use stacked branches for dependent work units. Serialize integration when units share files or mutable state.
- Run commands that can write user, system, or tool-managed paths against a dummy tree, temporary target directory, or isolated fixture.
- Bind every environment variable, configuration value, and command option that can affect runtime paths or state to the isolated target before running commands.
- Use the platform's standard temporary-directory mechanism for disposable targets. Register cleanup before the first target mutation.
- Keep runtime repositories, caches, history, state, credentials, and generated files outside tracked sources.
- Do not point development commands at live user or system paths.
- Remove disposable targets after execution.

## Orchestration Artifacts

- Coordinate multi-step or multi-agent work through a shared temporary directory; prefer a repository-scoped location (for example, `.agents/projects/<project>/tmp/` — see the `agentic-projects` skill for the path convention) when artifacts should be inspectable during the task, and a session-scoped location otherwise.
- Clean up temporary artifacts when the task is complete unless explicitly asked to persist them.
