---
name: mise-bootstrap-lifecycle
description: Use when changing the repository's canonical system:bootstrap task, init shim, bootstrap hooks, installer behavior, phase order, confirmations, or fail-fast recovery.
---

# Mise Bootstrap Lifecycle

Use this skill for the canonical `system:bootstrap` task and the `scripts/init.zsh` acquisition shim.

## Lifecycle owner

- Keep `scripts/tasks/system/bootstrap.zsh` as the canonical task that selects the profile, confirms the operation, and runs the full bootstrap.
- Keep `scripts/init.zsh` as the first-run mise acquisition and compatibility forwarding shim.
- Run the full repository-scoped bootstrap without script-maintained phase filters.
- Let mise declarations and module hooks own package installation, repository application, dotfile application, tool installation, and repeatable maintenance.
- Keep lifecycle hooks in the module that owns the related resource.
- Do not add script-maintained phase allowlists when a declaration already belongs to the full bootstrap lifecycle.

Read the [mise bootstrap run order](https://mise.jdx.dev/bootstrap.html#run-order) and [mise hooks reference](https://mise.jdx.dev/bootstrap.html#hooks) before changing lifecycle behavior.

Preserve the installer branch behavior. A newly installed mise does not self-update during the same run. An existing mise self-updates before bootstrap.

## Confirmation and errors

- Keep one confirmation boundary for existing-mise self-update and the full bootstrap.
- A declined confirmation must perform no later mutation.
- Preserve fail-fast behavior and explicit errors.
- Report missing mise, failed installation, and failed bootstrap as errors.
- Document that bootstrap is not transactional. Earlier phases remain applied when a later phase fails.
- Recover by fixing the reported phase and rerunning `./scripts/init.zsh --mise`.

## Hooks and maintenance

- Put package maintenance in the shared package module's `post-packages` hook.
- Put tool maintenance in the control-plane module's `post-tools` hook.
- Put application cache rebuilds in the owning module's `post-dotfiles` hook.
- Keep hooks repeatable and safe to run on every bootstrap.
- Set hook-invoked tasks to quiet unless their output is an intentional user-facing result.
- Do not duplicate hook commands in `scripts/mise.zsh`.
- Keep link cleanup scoped to an additive tracked historical path inventory, exclude mise runtime state, support dry runs, and resolve physical source containment before removal.

## Validation

- Run `zsh -n scripts/init.zsh` and `zsh -n scripts/tasks/system/bootstrap.zsh`.
- Run `tests/scripts/test_mise_bootstrap_lifecycle.zsh`.
- Run `tests/scripts/test_mise_config.zsh`.
- Preview both `work` and `personal` full bootstrap plans.
- Verify that a bootstrap error prevents later work.
- Run `mise run fix` after the focused tests pass.
