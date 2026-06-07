# AI Agent Interaction Rules

## Core Principles

- Prioritize technical accuracy and facts over validating beliefs.
- Provide honest, objective feedback even when it may not align with expectations.
- Investigate uncertainty first rather than confirming assumptions.
- Apply rigorous standards consistently to all ideas.
- Critique plans and implementations; do not merely validate them. Surface blind spots, weak assumptions, edge cases, and sequencing risks even when the work appears correct.
- **Critique gate (required terminal step):** After validation passes, run a fresh critique pass over every produced artifact before writing the final response. Ask: does the change do what was asked, are there edge cases missed, are any assumptions unverified? Validation answers "does it parse/run"; critique answers "is it right". Do not treat a passing validation as done — the critique pass is the stopping signal.
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
- Place the recommended option first; order the remainder by likely preference.
- Use the active harness's structured ask capability (for example, a question-with-options tool) when it is available and the choices are mutually exclusive; otherwise present them as a numbered list in prose.
- Keep each option short and self-explanatory; reserve free-text input for divergent answers.

### When tool calls are rejected or refused

This protocol applies to permission denials, policy refusals, and explicit user rejections of a tool call — not to ordinary task failures (failing tests, missing dependencies, transient errors), which follow normal debugging behavior.

1. **STOP** the current approach immediately.
2. **ASK** what changed and what outcome is preferred.
3. **WAIT** for instructions before proceeding.
4. **DO NOT** retry the same approach without new information.

## Tool Usage

- Never bypass repository hooks (`--no-verify` or equivalent).
- Prefer dedicated tools (linters, language servers, formatters, refactoring tools, file-discovery and edit tools) over ad-hoc shell commands.
- When configuring or extending a tool's behavior, check the tool's own documentation for a native directive, field, or option that already expresses the intent before writing scripts, wrappers, or runtime workarounds. Apply this during planning and during implementation. Prefer the native mechanism — declarative config surfaces in the tool's own introspection and survives upgrades better than equivalent custom logic.
- Minimize command output using quiet/no-pager flags and targeted filtering supported by the active environment.
- Combine independent tool calls in parallel; sequence calls only when later parameters depend on earlier results. Do not artificially serialize independent operations to "be safe" — parallelism is the default for independent work.

## Skills

The skills below are available under `.agents/skills/`.

- **MUST NOT** preload any skill in this index. Load any skill on demand when its description or use-when criteria match the current task; load multiple when several apply.
- Keep this index synchronized with the contents of `.agents/skills/`; when adding, renaming, or removing a skill, update this section in the same change. Each entry must use the skill's frontmatter `name` and a one-line summary of its `description`.
- For changes to this file, any listed skill, subagent/agent definitions, or other rule entrypoints, use the `agent-instructions-authoring` skill as the canonical source.

### Index

- `agent-instructions-authoring` — Author, audit, and modify agent instruction files (skills, `AGENTS.md`, `CLAUDE.md`, subagent/agent definitions); consolidate duplicated rules; validate skill metadata and discoverability.
- `agentic-projects` — Organize per-repo agentic project workspaces under `.agents/projects/<project>/` (prompts, plans, research, temporary artifacts).
- `coding-guidelines` — Apply repository coding standards when adding features, fixing bugs, refactoring, updating tests, or resolving lint/type/build issues.
- `commit-guidelines` — Create branches and commits from local diffs using project commit-message conventions (Conventional Commits, commitlint).
- `github-cli` — Use the `gh` CLI for pull requests, issues, workflow runs, releases, repository metadata, and file content on GitHub; invoke when interacting with any GitHub resource from the terminal.
- `hammerspoon` — Apply Hammerspoon macOS automation and window management rules when working with scripts, Spoons, hotkeys, or Lua code.
- `linting` — Run linters and respond to lint failures across languages and hook-managed projects; covers `hk` step-level invocation and changed-file vs. whole-tree scope.
- `lua` — Apply Lua authoring conventions for Neovim, Hammerspoon, WezTerm, and Yazi configurations (module structure, returns, EmmyLua annotations).
- `markdown` — Apply Markdown authoring conventions (clarity, link style, table-of-contents discipline).
- `migrate-to-rsbuild` — Migrate Webpack, Vite, CRA/CRACO, or Vue CLI projects to Rsbuild.
- `migrate-to-rslib` — Migrate TypeScript library projects from tsc or tsup to Rslib.
- `migrate-to-rslint` — Migrate ESLint or other lint setups to Rslint, including config, scripts, and editor integration.
- `migrate-to-rstest` — Migrate Jest or Vitest test suites and configuration to Rstest equivalents.
- `mise-tasks` — Add, modify, or invoke mise tasks (file tasks and TOML tasks); wire task help via usage directives; run tasks with mise run.
- `nvim` — Apply LazyVim Neovim configuration rules when working with config files, plugins, or Lua modules.
- `node-npm-bun` — Guide Node package-manager execution across bun, npm, and bunx/npx. Use when installing dependencies, running scripts, or invoking Node CLIs, while preferring bun/bunx when available and respecting project standards.
- `opencode-copilot-multipliers` — Sync GitHub Copilot model alias multiplier labels in the OpenCode config with current `github/docs` paid multipliers.
- `planning` — Produce execution-ready implementation plans for multi-step, high-risk, ambiguous, or multi-file/service work.
- `pr-guidelines` — Push branches and open pull requests using the project's title/body conventions and linked issues.
- `project-overview` — Discover project structure, architecture, and tooling before implementation in an unfamiliar area.
- `rewrite-imports` — Bulk-migrate import paths after module renames, file moves, or package refactors; use when changing how modules are referenced across many files.
- `rsbuild-best-practices` — Apply Rsbuild configuration, CLI, type-checking, optimization, asset handling, and debugging best practices.
- `rsbuild-v2-upgrade` — Upgrade Rsbuild projects from v1.x to v2, including dependency and configuration updates.
- `rsdoctor-analysis` — Analyze local `rsdoctor-data.json` bundle reports and produce evidence-based optimization recommendations.
- `rslib-best-practices` — Apply Rslib configuration, CLI, output, declaration, dependency, and build optimization best practices.
- `rslib-modern-package` — Apply modern JS/TS npm package conventions for Rslib libraries and release readiness.
- `rspack-best-practices` — Apply Rspack configuration, CLI, type-checking, CSS, optimization, asset, and profiling best practices.
- `rspack-debugging` — Debug Rspack crashes and hangs (including segmentation faults) with LLDB-focused workflows.
- `rspack-split-chunks` — Diagnose and optimize Rspack `optimization.splitChunks` settings for chunking, caching, and deduplication.
- `rspack-tracing` — Diagnose Rspack build failures and performance bottlenecks with tracing and profiling workflows.
- `rspack-v2-upgrade` — Upgrade Rspack projects from v1.x to v2, including dependency and configuration updates.
- `rspress-best-practices` — Apply Rspress best practices for config, content, MDX, theming, i18n, search, and deployment.
- `rspress-custom-theme` — Customize Rspress themes via CSS variables, layout slots, component wrapping, and theme ejection.
- `rspress-description-generator` — Generate and maintain Rspress page description frontmatter for SEO and metadata quality.
- `rspress-v2-upgrade` — Migrate Rspress projects from v1 to v2 and validate config/theme compatibility.
- `rstest-best-practices` — Apply Rstest best practices for test authoring, mocking, snapshots, DOM testing, coverage, CI, and performance.
- `rstest-debugging` — Debug Rstest failures and performance regressions with startup-vs-execution isolation and controlled experiments.
- `scripts` — Author and maintain setup, automation, and bootstrap shell/task scripts and install flows.
- `security` — Apply security checks for secrets, credentials, permissions, external network access, dependency risk, and sensitive configuration; use during implementation and security review passes.
- `task-orchestration` — Decide when to parallelize tool calls, when to dispatch subagents, which model tier suits each sub-task, and how to coordinate multi-step work via shared temporary artifacts.
- `tanstack-cli` — Use TanStack CLI for app scaffolding, add-on management, docs lookup, and MCP migration whenever a project uses TanStack tools or the user asks for TanStack workflows.
- `zsh` — Apply Zsh shell scripting conventions (error safety, logging helpers); use when authoring or modifying Zsh scripts.
