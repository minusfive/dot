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
- Aggregate and reconcile outputs from multiple subagents before applying changes.
- Ask workers for concise progress reports with changed files, completed work, validation evidence, divergence, blockers, and remaining scope.
- Check progress at each checkpoint. Compare results with the estimate, scope, and acceptance checks.
- If an agent cannot deliver, do not take over its assigned work. Use the drift recovery sequence or report a blocker and next action.

## Drift Recovery

- When a worker drifts from its assignment, request a progress report. Tell it to make no further edits and stop after reporting.
- Treat a missed checkpoint, scope growth, or an expired estimate as drift.
- Do not change the plan and send the same worker new instructions.
- Include completed work, changed files, validation evidence, drift, blockers, remaining scope, and branch or worktree state in the report.
- Assign a separate critique worker to assess the report, changes, and validation evidence. Ask whether to keep, discard, or rework the progress, with reasons.
- Wait for the critique before you change the plan, ownership, or dependencies.
- Assign a bounded planning worker to update the plan from the critique. Have an independent critic review the patch when the workflow requires it.
- Accept the updated plan, then assign remaining work to new workers with clear boundaries.
- Preserve work that the critique recommends keeping. Discard only isolated, agent-owned changes that the critique finds unusable.
- If the worker cannot report, stop it before critique. Use available evidence, state what is missing, and do not restart it on the same assignment.

## Model Selection

- Use the orchestrator's model for every subagent unless I tell you otherwise.

## Runtime isolation

- Use a separate worktree for each execution scope that changes repository files. Keep parallel worktrees independent.
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
