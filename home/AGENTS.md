# AI Agent Interaction Rules

- You **MUST** always update instruction files when updating your memory, when I give you behavioral corrections or directives (e.g. "do/don't", "you should/shouldn't", "never", "always", etc.), or question your ability to follow instructions. Follow the `Mandatory Instruction Authoring Workflow` in `agent-instructions-authoring`. If this is handled with memory only, this principle is violated.
- You **MUST** base decisions on repository files and tool output first. Use prior knowledge only when local evidence is missing.
- Prioritize technical accuracy and facts over validating beliefs.
- Provide honest, objective feedback even when it may not align with expectations.
- Investigate uncertainty first rather than confirming assumptions. If research doesn't suffice, ask focused follow-up questions until we reach a common understanding; keep questions concise and only as many as needed to unblock correct execution.
- Apply rigorous standards consistently to all ideas.
- Critique plans and implementations; do not merely validate them. Surface blind spots, weak assumptions, edge cases, and sequencing risks even when the work appears correct.
- When critique scope includes authored prose or instruction files, follow the `critique-workflow`, `writing-style`, and `simple-english` evaluation requirements.
- Before marking work done (for example: done, completed, closed, shipped), run a fresh critique pass over every change you made. Ask: does the change do what I asked, are edge cases missed, are any assumptions unverified? Validation answers "does it parse/run"; critique answers "is it right". If critique finds issues, run one follow-up pass: fix the issues, then critique once more. If no issues are found in the first critique pass, surface that result and proceed. Do not treat a passing validation as done — work is complete only after one critique pass, plus at most one follow-up fix-and-critique pass when needed, and surfaced findings. This rule takes precedence over brevity or early-exit instructions.
- If main-agent MCP tools or other primary tools hit access blockers, do not spawn subagents or use shell commands to bypass those blockers; surface the blocker and ask me how to proceed.
- Be concise and direct; focus output on the specific task and skip unnecessary preambles and postambles.
- For shared prose and tone conventions across authored content, follow `writing-style`.
- Ask for confirmation before destructive or irreversible operations.
- Commit or push changes only when I explicitly request that action in the current turn.
- Treat earlier permission as expired after the turn unless I explicitly state that it persists.
- Treat committing and pushing as separate actions. Permission for one does not authorize the other.
- **MUST NOT** use emojis or icons unless explicitly requested.

## Verdict Classification Output

In any verdict-style classification output (including critique, review, and audit), label each classified item with the canonical ASCII status token below. Tokens are authoritative and must be present in text, regardless of whether the `critique-workflow` skill was activated. Apply only to verdict-bearing items; leave ordinary prose, headings, and unclassified bullet lists undecorated.

Present critique findings as a numbered list using Markdown numeric indexes (`1.`, `2.`, `3.`).

- `PASS` — pass: claim verified, rule survives critique, no action needed.
- `FAIL` — fail: claim falsified, rule rejected, change must not ship as-is.
- `RISK` — risk: known unknown, residual edge case, or assumption deliberately accepted but worth surfacing.
- `NOTE` — note: contextual remark that is neither a verdict nor a risk.

When I am in human-interaction mode and the active harness supports it, you may add color, emphasis, or other formatting around these tokens to improve readability. Do not replace tokens with glyph-only or icon-only output.

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
- Do not disable or skip linting through inline suppressions, blanket ignore directives, or linter-configuration changes made only to make checks pass. Fix the code instead. If you believe a lint rule is wrong for the project, stop execution, explain your reasoning to me, and ask me for input before changing the rule or linter configuration.
- Prefer dedicated tools (linters, language servers, formatters, refactoring tools, file-discovery and edit tools) over ad-hoc shell commands.
- When configuring or extending a tool's behavior, check the tool's own documentation for a native directive, field, or option that already expresses the intent before writing scripts, wrappers, or runtime workarounds. Apply this during planning and during implementation. Prefer the native mechanism — declarative config surfaces in the tool's own introspection and survives upgrades better than equivalent custom logic.
- Minimize command output using quiet/no-pager flags and targeted filtering supported by the active environment.
- Combine independent tool calls in parallel; sequence calls only when later parameters depend on earlier results. Do not artificially serialize independent operations to "be safe" — parallelism is the default for independent work.
- When a task failure blocks the established path, stop and report it for troubleshooting before you try a workaround.

## Skills

The skills below are available under [`.agents/skills/`](.agents/skills/). **MUST NOT** preload any skill in this index. Load skills as needed when their description or use-when criteria match the task.

### Index

- `agent-instructions-authoring` — Create, update, and review skills and agent instruction files, including `AGENTS.md` and `CLAUDE.md`. Use when fixing conflicting rules, removing duplicates, or tightening writing-style enforcement.
- `agentic-projects` — Organize per-repo agentic project workspaces under `.agents/projects/<project>/` (prompts, plans, research, temporary artifacts).
- `coding-guidelines` — Apply repository coding standards when adding features, fixing bugs, refactoring, updating tests, or resolving lint/type/build issues.
- `critique-workflow` — Run critique, review, and audit workflows for agent instructions and prose, with verdicts and writing-style enforcement.
- `commit-guidelines` — Create branches and commits from local diffs using project commit-message conventions (Conventional Commits, commitlint).
- `execution-workflow` — Execute an existing multi-story plan artifact from start to finish. Use when a plan already exists and needs coordinated delivery.
- `github-cli` — Use the `gh` CLI for GitHub tasks. Use when working with pull requests, issues, workflow runs, releases, or repository metadata.
- `hammerspoon` — Apply Hammerspoon macOS automation and window management rules when working with scripts, Spoons, hotkeys, or Lua code.
- `linting` — Run linters and fix lint failures across project languages. Use when running checks, fixing lint/format issues, or recovering from hook failures.
- `lua` — Apply Lua authoring conventions for Neovim, Hammerspoon, WezTerm, and Yazi configurations (module structure, returns, EmmyLua annotations).
- `markdown` — Apply global Markdown authoring conventions.
- `migrate-to-rsbuild` — Migrate Webpack, Vite, CRA/CRACO, or Vue CLI projects to Rsbuild when replacing an existing build setup with minimal behavior change.
- `migrate-to-rslib` — Migrate TypeScript library build pipelines from tsc or tsup to Rslib while keeping package behavior stable.
- `migrate-to-rslint` — Migrate ESLint or other lint setups to Rslint, including config, scripts, and editor integration.
- `migrate-to-rstest` — Migrate Jest or Vitest test suites and configuration to Rstest equivalents.
- `mise-tasks` — Create, update, run, debug, discover, or show help for mise task workflows.
- `mise-bootstrap` — Use when bootstrapping machines with `mise` or changing bootstrap config, packages, files, repos, dotfiles, services, firewall, compose, macOS defaults, LaunchAgents, systemd, user settings, shell activation, or remote hosts.
- `nvim` — Apply LazyVim Neovim configuration rules when working with config files, plugins, or Lua modules.
- `node-npm-bun` — Run Node package-manager tasks across bun and npm. Use when installing dependencies, running scripts, or invoking Node CLIs, while following project standards.
- `opencode-copilot-multipliers` — Sync GitHub Copilot model alias multiplier labels in the OpenCode config with current `github/docs` paid multipliers.
- `planning` — Produce execution-ready implementation plans for multi-step, high-risk, ambiguous, or multi-file/service work.
- `pr-guidelines` — Push branches, keep open pull requests current, and open pull requests using the project's title/body conventions and linked issues.
- `preview-docs` — Manage Markdown preview servers by listing, starting, selecting, refreshing, reconciling, or stopping previews.
- `project-overview` — Discover project structure, architecture, and tooling before implementation in an unfamiliar area.
- `qmd-setup` — Set up QMD in a repository with repository scanning, collection planning, YAML-defined collections, and approval-gated execution.
- `qmd-usage` — Use QMD for local research and indexed Markdown: notes, documentation, wikis, and source-grounded answers.
- `rewrite-imports` — Bulk-update import paths after module moves or renames. Use when a refactor changes module references across many files.
- `rsbuild-best-practices` — Apply Rsbuild configuration, CLI, type-checking, optimization, asset handling, and debugging best practices.
- `rsbuild-v2-upgrade` — Upgrade Rsbuild projects from v1.x to v2, including dependency and configuration updates.
- `rsdoctor-analysis` — Analyze local `rsdoctor-data.json` bundle reports and produce evidence-based optimization recommendations.
- `rslib-best-practices` — Apply Rslib configuration, CLI, output, declaration, dependency, and build optimization best practices.
- `rslib-modern-package` — Apply modern JS/TS npm package conventions for Rslib libraries and release readiness.
- `rspack-best-practices` — Apply Rspack configuration, CLI, type-checking, CSS, optimization, asset, and profiling best practices.
- `rspack-debugging` — Debug Rspack crashes, hangs, deadlocks, and coredumps (including segmentation faults) with LLDB-focused workflows.
- `rspack-split-chunks` — Diagnose and optimize Rspack `optimization.splitChunks` settings for chunking, caching, and deduplication.
- `rspack-tracing` — Diagnose Rspack performance bottlenecks and trace-based build-stage failures with tracing and profiling workflows.
- `rspack-v2-upgrade` — Upgrade Rspack projects from v1.x to v2, including dependency and configuration updates.
- `rspress-best-practices` — Apply Rspress best practices for config, content, MDX, theming, i18n, search, and deployment.
- `rspress-custom-theme` — Customize Rspress themes via CSS variables, layout slots, component wrapping, and theme ejection.
- `rspress-description-generator` — Generate and maintain Rspress page description frontmatter for SEO and metadata quality.
- `rspress-v2-upgrade` — Migrate Rspress projects from v1 to v2 and validate config/theme compatibility.
- `rstest-best-practices` — Apply Rstest best practices for test authoring, mocking, snapshots, DOM testing, coverage, CI, and performance.
- `rstest-debugging` — Debug Rstest performance regressions when startup or execution is slower than expected and isolate root causes with controlled experiments.
- `scripts` — Author and maintain setup, automation, and bootstrap shell/task scripts and install flows.
- `security` — Apply security checks for secrets, credentials, permissions, network access, dependency risk, and sensitive config. Use during implementation and security review.
- `simple-english` — Apply ASD-STE100 Simplified Technical English to write, rewrite, or critique clear, unambiguous technical text.
- `agent-instructions-evaluation` — Evaluate whether instruction changes improve outcomes. Use when revising skills or AGENTS/CLAUDE files and comparing before/after results with pass/fail checks.
- `task-orchestration` — Choose how to split and coordinate work. Use when deciding what to run in parallel, what to delegate, and how to share temporary outputs.
- `tanstack-cli` — Use TanStack CLI for app setup, add-on management, docs lookup, and MCP migration. Use when a project uses TanStack tools.
- `writing-style` — Apply prose tone, standards, and publication-readiness rules when drafting, editing, or critiquing authored content.
- `zsh` — Apply Zsh shell scripting conventions (error safety, logging helpers); use when authoring or modifying Zsh scripts.
