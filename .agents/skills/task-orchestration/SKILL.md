---
name: task-orchestration
description: Decide when to parallelize tool calls, when to spawn, launch, or dispatch subagents instead of running directly, which model tier (higher- vs lower-capability) suits each sub-task, and how to coordinate multi-step work via shared scratch, temp, or orchestration directories. Use when fanning out concurrent tool calls, delegating scopes to subagents, picking a capability tier for sub-work, or sharing intermediate files across steps.
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

- Choose the lowest-cost model that can reliably meet the task quality bar.
- Use faster/cheaper models for narrow, low-risk, repetitive, or format-constrained work.
- Use higher-capability models for ambiguous requirements, cross-file reasoning, architecture decisions, safety-critical changes, or failure recovery.
- When splitting work across subagents, match model capability to each sub-task instead of using one tier for everything.

## Orchestration Artifacts

- Coordinate multi-step or multi-agent work through a shared temporary directory; prefer a repository-scoped location (for example, `.agents/projects/<project>/tmp/` — see the `agentic-projects` skill for the path convention) when artifacts should be inspectable during the task, and a session-scoped location otherwise.
- Clean up temporary artifacts when the task is complete unless explicitly asked to persist them.
