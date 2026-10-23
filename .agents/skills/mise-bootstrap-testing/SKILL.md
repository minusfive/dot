---
name: mise-bootstrap-testing
description: Use when adding or updating tests for mise bootstrap modules, profiles, lifecycle hooks, ownership, dry runs, runtime exclusions, or repository configuration.
---

# Mise Bootstrap Testing

Use this skill for tests under `tests/scripts/` that verify the repository's mise bootstrap configuration.

## Test boundaries

- Keep declaration-only package, tool, and profile cases in `tests/scripts/test_mise_bootstrap_modules.zsh`.
- Add a separate `tests/scripts/test_mise_bootstrap_<name>.zsh` file only when a module needs behavior, ownership, runtime exclusion, syntax, or lifecycle assertions beyond the shared declaration contract.
- Keep lifecycle checks in `test_mise_bootstrap_lifecycle.zsh`.
- Keep shared lifecycle task checks in `test_mise_task_bootstrap.zsh`.
- Keep global control-plane checks in `test_mise_bootstrap_mise.zsh`.
- Keep profile checks with the profile or lifecycle test that owns the behavior.
- Use `mise_test_helpers.zsh` for shared root setup and assertion helpers.

## Assertions

The shared module contract test must verify the facts that can drift:

- the module file exists;
- the declaration has the expected resource type;
- `mise.toml` deploys the module;
- native `mise` environment fragments select the module;
- personal-only modules stay out of the work profile.

A behavior-specific module test must verify the additional facts that can drift:

- local development files stay outside deployed targets;
- tool-owned runtime files stay outside tracked sources; and
- the deployed target has the expected ownership and link mode when the test runs on a configured machine.

Use exact source and target paths when they define ownership. Use dry runs for non-mutating profile and lifecycle checks.

## Lifecycle fixtures

Use command stubs when a test needs to verify script behavior:

- record command arguments in a temporary log;
- record the expected repository context;
- cover declined confirmation;
- cover installer and existing-mise branches;
- cover bootstrap failure; and
- verify that later hooks or maintenance do not run after failure.

Do not print credentials, runtime databases, or other sensitive file contents.

## Run order

1. Run `test_mise_bootstrap_modules.zsh` when a module declaration or profile list changes.
2. Run the changed behavior-specific test when module behavior changes.
3. Run the related profile or lifecycle test.
4. Run `mise run fix`.

Use the [mise bootstrap reference](https://mise.jdx.dev/bootstrap.html) and [mise task configuration reference](https://mise.jdx.dev/tasks/task-configuration.html) for command behavior. Keep test assertions aligned with current mise output and repository configuration.
