---
name: mise-bootstrap-lifecycle
description: Use when changing the repository's mise initialization lifecycle, scripts/mise.zsh, bootstrap hooks, installer behavior, phase order, confirmations, or fail-fast recovery.
---

# Mise Bootstrap Lifecycle

Use this skill for the full mise phase selected by `./scripts/init.zsh --mise`.

## Lifecycle owner

- Keep `scripts/mise.zsh` as the bridge that installs mise, selects the repository context, confirms the operation, and runs the full bootstrap.
- Preserve the existing repository-scoped context and task resolution. Read `scripts/mise.zsh` and its lifecycle tests before changing them.
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
- Do not duplicate hook commands in `scripts/mise.zsh`.

## Validation

- Run `zsh -n scripts/init.zsh` and `zsh -n scripts/mise.zsh`.
- Run `tests/scripts/test_mise_bootstrap_lifecycle.zsh`.
- Run `tests/scripts/test_mise_config.zsh`.
- Preview both `work` and `personal` full bootstrap plans.
- Verify that a bootstrap error prevents later work.
- Run `mise run fix` after the focused tests pass.
