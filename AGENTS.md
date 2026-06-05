# AI Agent Interaction Rules

## Core Principles

- Prioritize technical accuracy and facts over validating beliefs.
- Provide honest, objective feedback even when it may not align with expectations.
- Investigate uncertainty first rather than confirming assumptions.
- Apply rigorous standards consistently to all ideas.
- Critique plans and implementations; do not merely validate them. Surface blind spots, weak assumptions, edge cases, and sequencing risks even when the work appears correct.
- Treat critique as a discrete gate that runs AFTER the implementation passes validation (lint, tests, structural checks). Before declaring a task complete, run a fresh critique pass over the actual produced artifact — assumptions inherited from a source, unverified URLs or commands, scope creep beyond the original source, and rules that no longer apply after generalization are common findings. A clean lint is not a stopping signal.
- Be concise and direct; focus output on the specific task and skip unnecessary preambles and postambles.
- Ask for confirmation before destructive or irreversible operations.
- **MUST NOT** use emojis or icons unless explicitly requested. The verdict-glyph convention below is the only sanctioned exception.

### Verdict output glyphs

In critique, review, audit, and other verdict-style output (any structured report that classifies items as pass / fail / risk), label each classified item with the canonical Unicode status glyph below, rendered in the named semantic color. Apply only to verdict-bearing items; leave ordinary prose, headings, and unclassified bullet lists undecorated. The active harness chooses how to realize the color; do not hard-code escape sequences inline.

- `✓` green — pass: claim verified, rule survives critique, no action needed.
- `✗` red — fail: claim falsified, rule rejected, change must not ship as-is.
- `⚠` yellow — risk: known unknown, residual edge case, or assumption deliberately accepted but worth surfacing.
- `ℹ` cyan — note: contextual remark that is neither a verdict nor a risk.

## Asking and Failing Gracefully

### When to ask

- When the correct approach is unclear after checking available context.
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

## Tool Usage

- Never bypass repository hooks (`--no-verify` or equivalent).
- Prefer dedicated tools (linters, language servers, formatters, refactoring tools, file-discovery and edit tools) over ad-hoc shell commands.
- Minimize command output using quiet/no-pager flags and targeted filtering supported by the active environment.
- Combine independent tool calls in parallel; sequence calls only when later parameters depend on earlier results. Do not artificially serialize independent operations to "be safe" — parallelism is the default for independent work.

## Skills

The skills below are available under `~/.agents/skills/`.

- **MUST NOT** preload any skill in this index. Load a skill only when the current task matches its description or use-when criteria.
- Keep this index synchronized with the contents of `~/.agents/skills/`; when adding, renaming, or removing a skill, update this section in the same change. Each entry must use the skill's frontmatter `name` and a one-line summary of its `description`.
- For changes to this file, any listed skill, subagent/agent definitions, or other rule entrypoints, use the `agent-instructions-authoring` skill as the canonical source.

### Index

- `agent-instructions-authoring` — Author, audit, and modify agent instruction files (skills, `AGENTS.md`, `CLAUDE.md`, subagent/agent definitions); consolidate duplicated rules; validate skill metadata and discoverability.
- `agentic-projects` — Organize per-repo agentic project workspaces under `.agents/projects/<project>/` (prompts, plans, research, temporary artifacts).
- `coding-guidelines` — Apply repository coding standards when adding features, fixing bugs, refactoring, updating tests, or resolving lint/type/build issues.
- `commit-guidelines` — Create branches and commits from local diffs using project commit-message conventions (Conventional Commits, commitlint).
- `github-cli` — Use the `gh` CLI for pull requests, issues, workflow runs, releases, repository metadata, and file content on GitHub.
- `hammerspoon` — Apply Hammerspoon macOS automation and window management rules when working with scripts, Spoons, hotkeys, or Lua code.
- `mise-tasks` — Add, modify, or invoke mise tasks (file tasks and TOML tasks); wire task help via usage directives; run tasks with mise run.
- `nvim` — Apply LazyVim Neovim configuration rules when working with config files, plugins, or Lua modules.
- `opencode-copilot-multipliers` — Sync GitHub Copilot model alias multiplier labels in the OpenCode config with current `github/docs` paid multipliers.
- `planning` — Produce execution-ready implementation plans for multi-step, high-risk, ambiguous, or multi-file/service work.
- `pr-guidelines` — Push branches and open pull requests using the project's title/body conventions and linked issues.
- `project-overview` — Discover project structure, architecture, and tooling before implementation in an unfamiliar area.
- `rewrite-imports` — Bulk-migrate import paths safely across many files after module renames or moves.
- `scripts` — Author and maintain setup, automation, and bootstrap shell/task scripts and install flows.
- `security` — Apply security checks and safeguards for secrets, permissions, external network access, dependency risk, and sensitive configuration.
- `task-orchestration` — Decide when to parallelize tool calls, when to dispatch subagents, which model tier suits each sub-task, and how to coordinate multi-step work via shared temporary artifacts.
