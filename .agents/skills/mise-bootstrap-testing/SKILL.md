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

## Fixture isolation

- Create every disposable fixture through `test_fixture_dir` or a helper that delegates to it.
- Keep fixture roots outside the repository and its worktrees. The helper creates unique directories under `${TMPDIR:-/tmp}`.
- Ignore `prunable` entries only when their paths no longer exist. Reject every existing repository or worktree path, including paths marked `prunable`, and fail closed on command errors.
- Register the owning trap or cleanup immediately after fixture creation.
- Remove only paths that the fixture created. Do not remove pre-existing paths.
- Create fixtures at runtime. Use a checked-in fixture tree only when a stable fixture is explicitly required.
- Do not create `.test-*`, `.test-tmp`, or other fixture roots in a repository or worktree.

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

Use exact source and target paths when they define ownership. Use dry runs for non-mutating profile and lifecycle plans, not as proof that hooks execute.

Test environment-backed profile choices through both `MISE_ENV=<profile>` and `mise -E <profile>`. Add explicit `--profile` forwarding or imperative validation only when an exact native invocation test shows that usage choices do not enforce the contract.

## Lifecycle fixtures

Use command stubs when a test needs to verify script behavior:

- record command arguments in a temporary log;
- record the expected repository context;
- cover declined confirmation;
- cover installer and existing-mise branches;
- cover bootstrap failure; and
- verify that later hooks or maintenance do not run after failure.

Do not print credentials, runtime databases, or other sensitive file contents.

When a fixture invokes network-enabled hooks, set `MISE_NO_HOOKS=1` for declarative configuration assertions and test hook behavior separately.

## Run order

1. Run `test_mise_bootstrap_modules.zsh` when a module declaration or profile list changes.
2. Run the changed behavior-specific test when module behavior changes.
3. Run the related profile or lifecycle test.
4. Run `mise run fix`.

Use the [mise bootstrap reference](https://mise.jdx.dev/bootstrap.html) and [mise task configuration reference](https://mise.jdx.dev/tasks/task-configuration.html) for command behavior. Keep test assertions aligned with current mise output and repository configuration.
