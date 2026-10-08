---
name: linting
description: Run project linters and handle lint/format failures. Use when baselining checks, fixing hook failures, scoping lint runs, or invoking `hk` lint steps.
---

# Linting

Use this skill whenever the task involves running, interpreting, or responding
to linters and formatters — whether invoked manually, through a project task
wrapper, or as part of a git hook.

## When to Run

- Run the project's linters before starting non-trivial edits to baseline any
  pre-existing failures unrelated to the task.
- Run them again before declaring work complete, as part of the critique gate
  defined in `AGENTS.md`.
- Re-run after every fix until the relevant linter exits clean.

## Responding to Failures

- Fix the root cause in the offending file.
- Follow the canonical lint-governance policy in `AGENTS.md` for suppressions,
  ignore directives, linter-configuration changes, and lint-rule-change
  escalation.
- Follow the hook-bypass rule in `AGENTS.md`: never pass `--no-verify` or any
  equivalent flag to skip a failing check.
- When a linter reports across multiple files, fix each file rather than
  reverting the change that surfaced the failures.

## Scoping a Run

- Prefer changed-file scope by default. Most repository runners are git-aware
  and lint only the modified set.
- Expand to whole-tree scope when the change is structural (renames, moves,
  config edits), when a linter complains about cross-file references, or when
  preparing a release candidate.

## Discovery

- Use the `project-overview` skill to locate linter configs, runner tasks, and
  CI workflows before invoking anything directly.
- Prefer project task wrappers (for example, invoking tasks via the
  `mise-run_task` MCP tool or `mise run <task>`) over invoking linters
  directly when wrappers exist — they encode the project's expected flags and
  exclusions.

## Projects Using `hk`

[`hk`](https://hk.jdx.dev/) drives both git hooks and on-demand checks in
projects that adopt it. Recognize it by a top-level `hk.pkl` file.

- Run all configured checks: `hk check` (read-only) or `hk fix` (auto-fix).
  Project task wrappers may shorten this to `check` and `fix` task
  invocations (for example, via `mise-run_task` or `mise run check` / `mise
run fix`); prefer the wrapper when present.
- Run a single step with `hk check -S <step>` (read-only) or `hk fix -S
<step>` (auto-fix). This is the right tool when iterating on a single
  linter's failures. The same `-S` flag is accepted by `hk run <hook>` when
  scoping inside a specific git hook.
- Default scope is changed files. Pass `-a` to expand the run to all tracked
  files (for example, `hk fix -a` or `hk check -S <step> -a`).
- Discover available hooks and step names from the project's `hk.pkl`, or
  from `hk --help` / `hk run --help`. Do not assume a fixed set across
  repositories.
- Defer to the [`hk` documentation](https://hk.jdx.dev/) for the full CLI
  surface and flag semantics.
