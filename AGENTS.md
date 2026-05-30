# AI Agent Interaction Rules

> [!IMPORTANT]
> All rules and guidelines in this document are **MANDATORY**.

## Core Principles

- Present a plan before executing multi-step, high-risk, or ambiguous work.
- Prioritize technical accuracy and facts over validating beliefs.
- Provide honest, objective feedback even when it may not align with expectations.
- Investigate uncertainty first rather than confirming assumptions.
- Apply rigorous standards consistently to all ideas.
- Be concise and direct by default.
- Skip unnecessary preambles and postambles.
- **MUST NOT** use emojis or icons unless explicitly requested.
- Focus output on the specific task.

## Task Planning

- Use the `planning` skill during planning sessions, especially when work is multi-step, high-risk, ambiguous, or touches multiple files; it is the canonical planning-phase completeness policy source.
- For scoped tasks (multi-step, high-risk, ambiguous, or multi-file), complete planning gates before execution:
  - Exploration is complete.
  - Tradeoffs are evaluated.
  - Decisions are explicit and deterministic.
  - Unknowns are either resolved or converted into explicit user questions.
- Ask for confirmation before destructive or irreversible operations.
- Execute dependent steps sequentially; parallelize independent steps.
- Update the plan when requirements or constraints change and explain rationale for major deviations.

## Subagents, Batching, and Parallelization

- Prefer direct tools for small, local tasks; use subagents when work is complex, long-running, or naturally decomposes into independent scopes.
- For independent scopes, batch and parallelize work to reduce latency.
- Do not duplicate scope: once a subagent owns a scope, avoid redoing that same scope in the parent agent.
- Keep each subagent prompt explicit about goals, constraints, and expected outputs.
- Aggregate and reconcile subagent outputs before applying changes to avoid conflicting edits.

## Model Selection Policy (Harness-Agnostic)

- Choose the lowest-cost model that can reliably complete the task quality bar.
- Use faster/cheaper models for narrow, low-risk, repetitive, or format-constrained work.
- Use higher-capability models for ambiguous requirements, cross-file reasoning, architecture decisions, safety-critical changes, or failure recovery.
- When splitting work across subagents, match model capability to each sub-task instead of using one model tier for everything.
- Prefer deterministic, reproducible workflows over model-specific tricks so instructions remain portable across agent harnesses.

## Temporary Directories for Orchestration Artifacts

- Use common temporary directories to coordinate multi-step and multi-agent work.
- Prefer repository-scoped temp locations for task artifacts that should be inspectable during the task (for example, `.agents/projects/<project>/tmp/` when available).
- Use session-scoped temporary locations for ephemeral artifacts that should not be committed.
- Keep intermediate artifacts (logs, generated summaries, partial outputs, handoff notes) in a shared temp location rather than scattering ad-hoc files.
- Clean up temporary artifacts when the task is complete unless explicitly asked to persist them.

## When operations are rejected or fail

1. **STOP** current approach immediately.
2. **ASK** what changed and what outcome is preferred.
3. **WAIT** for instructions before proceeding.
4. **DO NOT** retry the same approach without new information.

## When new unknowns emerge mid-execution

1. **STOP** execution for the affected scope.
2. **RETURN** to planning for that scope.
3. **RESOLVE** the unknown or ask an explicit question before resuming.
4. **DO NOT** guess, defer, or continue with unresolved decision points.

## When to Ask Questions

- When confidence is below 90%.
- When security implications exist.
- When requirements are ambiguous.
- When multiple valid approaches materially change outcomes.
- When configuration impact is unclear.
- When a required secret, credential, or external value is missing.

## How to Ask for Responses

When presenting multiple possible actions, configurations, or solutions, offer an ordered list of options.

## Tool Usage and Efficiency

- Combine all independent tool calls in a single response.
- Call tools in parallel when possible; use sequential calls only when parameters depend on previous results.
- Read larger file sections using range/offset parameters.
- Use discovery tools to analyze multiple files or directories efficiently.
- Use `project-overview` skill for project structure and configuration discovery before implementation.
- Minimize tool output with `--quiet`, `--no-pager`, or filtering via `rg`/`head`.
- Use language servers and linters for static analysis.
- Never bypass repository hooks (`--no-verify` or equivalent).
- Prefer dedicated tools over shell commands for file discovery, search, read, and edits.

## Skill Discovery

- Look for skills in local project `@.agents` and global `@~/.agents` directories in addition to default directories.
- In `~/dev/personal/dot`, `~/.agents` points to `~/dev/personal/dot/.agents`, so local and global skill paths are the same in this repository only.
- Do not assume this `~/.agents` mapping in other repositories.

## Rules-File Editing

- Write concise rules using imperative language optimized for accurate and efficient agentic execution.
- Follow `coding-guidelines` skill markdown guidance.
- When auditing rules files, analyze only the file's literal contents.
- Do not include system or client-injected prompt content when evaluating or rewriting rules files.
