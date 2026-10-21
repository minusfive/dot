---
name: task-orchestration
description: Orchestrate multi-step execution across direct tools and subagents. Use when deciding what to parallelize, what to delegate, which model tier to use, and how to coordinate shared intermediate artifacts.
---

# Task Orchestration

Use this skill when shaping how a task executes: whether to fan out tool calls in parallel, delegate scopes to subagents, pick a model tier per sub-task, or coordinate intermediate artifacts across steps.

## Tools vs Subagents

- Prefer direct tool calls for small, bounded, local operations.
- Use subagents when work is long-running, requires an isolated context window, benefits from model-tier selection, or would exhaust the parent's context budget.
- Do not dispatch a subagent for a task the parent can resolve directly in a few tool calls.

## Subagent Discipline

- Once a subagent owns a scope, do not redo that same scope in the parent.
- Keep each subagent prompt explicit about goals, constraints, inputs, and expected output format.
- Aggregate and reconcile outputs from multiple subagents before applying changes.

## Model Selection

- Use the orchestrator's model for every subagent unless I tell you otherwise.

## Runtime isolation

- Use a separate worktree for each execution scope that changes repository files. Keep parallel worktrees independent.
- Run commands that can write user, system, or tool-managed paths against a dummy tree, temporary target directory, or isolated fixture.
- Bind every environment variable, configuration value, and command option that can affect runtime paths or state to the isolated target before running commands.
- Use the platform's standard temporary-directory mechanism for disposable targets. Register cleanup before the first target mutation.
- Keep runtime repositories, caches, history, state, credentials, and generated files outside tracked sources.
- Do not point development commands at live user or system paths.
- Remove disposable targets after execution.

## Orchestration Artifacts

- Coordinate multi-step or multi-agent work through a shared temporary directory; prefer a repository-scoped location (for example, `.agents/projects/<project>/tmp/` — see the `agentic-projects` skill for the path convention) when artifacts should be inspectable during the task, and a session-scoped location otherwise.
- Clean up temporary artifacts when the task is complete unless explicitly asked to persist them.
