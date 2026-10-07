---
name: mise-tasks
description: Create, update, run, debug, discover, or show help for mise tasks, including task interfaces, usage directives, and output behavior.
---

# Mise Tasks

Use this skill whenever a request mentions a mise task or asks for task discovery, help, usage, flags, execution, authoring, or debugging.

This skill complements the `scripts` skill (broader script authoring, testing, and integration workflow). When both apply, prefer the more specific rule here for task-runner specifics and defer to `scripts` for general script structure.

## Discovery and Execution

- Use the mise CLI for discovery and help: list tasks with [`mise tasks`](https://mise.jdx.dev/cli/tasks.html) (alias `mise tasks ls`), inspect a task with `mise tasks info <task>`, and render task help with `mise run <task> --help` (or `-h`).
- Treat the `mise-run_task` MCP tool as execution-only. Pass a task name to execute a task. Do not use it for mise subcommands, task discovery, help, or metadata.
- Execute tasks by invoking the task runner directly (prefer the `mise-run_task` MCP tool when available; otherwise use `mise run <task>`).
- When your harness exposes direct MCP resource reads and you need structured metadata, read `mise://tasks` (for example, `source`, `config_sources`, and dependency fields).

## MCP Limitations and Fallbacks

- Treat `mise-install_tool` as optional; some mise versions report it as not implemented. When that happens, use the repository's normal CLI installation flow instead.
- During portability checks, confirm task origin from `mise://tasks` metadata or `mise tasks info` so you can distinguish repository tasks from user-global tasks.

## Authoring Conventions

Mise supports two task styles. Detect the style the project already uses and match it; do not introduce a second style without a clear reason.

### Script language selection

- Detect the project's preferred scripting language from existing task files and automation scripts before adding a new task.
- If project conventions are mixed or unclear, default to Bash for simple tasks because it is portable and simple.
- Reassess the language when task complexity grows; move to a better-fit language when Bash becomes hard to maintain.
- If a project's scripts are already standardized on one language, keep new scripts in that language unless a clear technical constraint requires otherwise.

### File tasks

See [file tasks](https://mise.jdx.dev/tasks/file-tasks.html).

- Place file tasks in the project's configured tasks directory; refer to the docs for the supported defaults and how `task_config.includes` overrides them.
- Make the file executable; mise auto-registers executable files in the tasks directory.
- Use a file extension that matches the task language/interpreter (for example `.zsh`, `.sh`, `.js`, `.ts`).
- Keep files named `_default` extensionless; mise default-task resolution breaks when `_default` has an extension.
- Detect the most appropriate non-task location for reusable script code from project conventions and existing layout before extracting shared logic.
- Shared script code belongs outside directories that mise scans for tasks. Anything mise discovers in those directories can become a task entry, so keep helpers/importable modules in the project's reusable-script location and import from there.

### TOML tasks

See [TOML tasks](https://mise.jdx.dev/tasks/toml-tasks.html).

- Define TOML tasks as `[tasks.<name>]` tables (one table per task) in `mise.toml` or `.mise.toml`.
- Configure metadata (`description`, `depends`, `env`, `sources`, `outputs`, `dir`, `usage`, `quiet`, etc.) per [task configuration](https://mise.jdx.dev/tasks/task-configuration.html).

## Usage and Help

- Prefer mise's [usage](https://usage.jdx.dev/) feature for argument parsing, option configuration, defaults, validation, and help on file tasks. Let usage own the task's interface; keep in-script code focused on the task's behavior rather than reimplementing argument parsing.
- Define the task interface with mise's usage directives appropriate to the task's language. Examples: `#USAGE` for shell file tasks, `//USAGE` for TypeScript file tasks, and the `usage` field on TOML tasks. See the [Arguments section](https://mise.jdx.dev/tasks/file-tasks.html#arguments) of the file-tasks docs.
- Rely on mise's native help rendering; do not implement custom help printing inside task scripts.
- Treat unknown or incomplete options as explicit errors.

## Output

- Set tasks to `quiet` by default so mise does not prefix task output with `[task-name]`. Use `quiet = true` for TOML tasks and the equivalent `#MISE quiet=true` directive for file tasks (or whichever directive syntax the task's language uses, per [task configuration](https://mise.jdx.dev/tasks/task-configuration.html)).
