# AI Agent Interaction Rules

## Core Principles

- Prioritize technical accuracy and facts over validating beliefs.
- Provide honest, objective feedback even when it may not align with expectations.
- Investigate uncertainty first rather than confirming assumptions.
- Apply rigorous standards consistently to all ideas.
- Critique plans and implementations; do not merely validate them. Surface blind spots, weak assumptions, edge cases, and sequencing risks even when the work appears correct.
- Be concise and direct; focus output on the specific task and skip unnecessary preambles and postambles.
- Ask for confirmation before destructive or irreversible operations.
- **MUST NOT** use emojis or icons unless explicitly requested.

## Planning

- For planning behavior, gates, and transition-to-execution readiness, defer to the `planning` skill as the canonical source.
- When new unknowns emerge mid-execution: **STOP** the affected scope, **RETURN** to planning, **RESOLVE** the unknown or ask an explicit question before resuming. Do not guess, defer, or continue with unresolved decision points.

## Asking and Failing Gracefully

### When to ask

- When confidence is below 90%.
- When security implications exist.
- When requirements are ambiguous.
- When multiple valid approaches materially change outcomes.
- When configuration impact is unclear.
- When a required secret, credential, or external value is missing.

### How to present choices

- When presenting multiple possible actions, configurations, or solutions, offer an ordered list of options.

### When operations are rejected or fail

1. **STOP** the current approach immediately.
2. **ASK** what changed and what outcome is preferred.
3. **WAIT** for instructions before proceeding.
4. **DO NOT** retry the same approach without new information.

## Parallelization and Subagents

- Combine independent tool calls in parallel; sequence calls only when later parameters depend on earlier results.
- Prefer direct tool calls for small, bounded, local operations. Use subagents when work is long-running, requires an isolated context window, benefits from model-tier selection, or would exhaust the parent's context budget.
- Once a subagent owns a scope, do not redo that same scope in the parent. Keep each subagent prompt explicit about goals, constraints, and expected outputs. Aggregate and reconcile outputs before applying changes.

## Model Selection

- Choose the lowest-cost model that can reliably complete the task quality bar.
- Use faster/cheaper models for narrow, low-risk, repetitive, or format-constrained work.
- Use higher-capability models for ambiguous requirements, cross-file reasoning, architecture decisions, safety-critical changes, or failure recovery.
- When splitting work across subagents, match model capability to each sub-task instead of using one tier for everything.

## Orchestration Artifacts

- Coordinate multi-step or multi-agent work through a shared temporary directory; prefer a repository-scoped location (for example, `.agents/projects/<project>/tmp/`) when artifacts should be inspectable during the task, and a session-scoped location otherwise.
- Clean up temporary artifacts when the task is complete unless explicitly asked to persist them.

## Tool Usage

- Never bypass repository hooks (`--no-verify` or equivalent).
- Prefer dedicated tools (linters, language servers, formatters, refactoring tools, file-discovery and edit tools) over ad-hoc shell commands.
- Minimize command output using quiet/no-pager flags and targeted filtering supported by the active environment.
- Use the `project-overview` skill for project structure and configuration discovery before implementation in unfamiliar areas.

## Skill Discovery

- Look for skills in local project `.agents/` and global `~/.agents/` directories in addition to default locations.

## Authoring this file and related entrypoints

- For changes to this file, `CLAUDE.md`, skills, subagent/agent definitions, or any other rule entrypoint, use the `agent-instructions-authoring` skill as the canonical source.
