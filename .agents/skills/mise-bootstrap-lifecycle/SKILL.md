---
name: mise-bootstrap-lifecycle
description: Use when changing native mise bootstrap, the mise environment shim, bootstrap hooks, installer behavior, phase order, confirmations, or fail-fast recovery.
---

# Mise Bootstrap Lifecycle

Use this skill for native `mise bootstrap`, the `scripts/mise-env.zsh` environment shim, and the `scripts/install-mise.zsh` installer.

## Lifecycle owner

- Keep native `mise bootstrap` as the canonical system bootstrap command.
- Keep `scripts/mise-env.zsh` responsible for repository-scoped mise environment setup before native bootstrap.
- Keep `scripts/install-mise.zsh` as the mise acquisition script. It must accept only `--help`, install mise when needed, and print the native bootstrap command.
- Select profiles with `-E` or `MISE_ENV` before calling native `mise bootstrap`.
- Validate the selected profile in each profile-sensitive bootstrap pre-hook.
- Let the control-plane dotfiles render the profile state and `~/.config/mise/miserc.local.toml` from the resolved profile during the dotfiles phase.
- Run the full repository-scoped bootstrap without script-maintained phase filters.
- Let mise declarations and module hooks own package installation, repository application, dotfile application, tool installation, and repeatable maintenance.
- Keep lifecycle hooks in the module that owns the related resource.
- Do not add script-maintained phase allowlists when a declaration already belongs to the full bootstrap lifecycle.

Read the [mise bootstrap run order](https://mise.jdx.dev/bootstrap.html#run-order) and [mise hooks reference](https://mise.jdx.dev/bootstrap.html#hooks) before changing lifecycle behavior.

Treat native `mise` behavior as the source of truth. Reproduce the exact `-E`, `MISE_ENV`, and task invocations before adding a wrapper, explicit argument forwarding, or imperative validation.

## Confirmation and errors

- Let native `mise bootstrap` own the main confirmation. Let the package and dotfile pre-hooks confirm their selected profiles. Do not add an imperative mise self-update step.
- A declined confirmation must perform no later mutation.
- Preserve fail-fast behavior and explicit errors.
- Report missing mise, failed installation, and failed bootstrap as errors.
- If a phase fails, fix the reported phase and rerun `mise -E <profile> bootstrap`, preserving the selected profile.
- A pre-bootstrapped machine may lack `miserc.local.toml`; the resolved profile fallback in `home/.config/mise/config.toml` must preserve the profile state until the selector is rendered.

## Hooks and maintenance

- Put package maintenance in the shared package module's `post-packages` hook.
- Keep profile validation and confirmation in the control-plane module's `pre-packages` hook.
- Keep profile validation in the control-plane module's `pre-dotfiles` hook.
- Put tool maintenance in the control-plane module's `post-tools` hook.
- Put application cache rebuilds in the owning module's `post-dotfiles` hook.
- Keep hooks repeatable and safe to run on every bootstrap.
- Treat `mise bootstrap --dry-run` as a plan that prints hook commands. Test hook execution through direct task calls or an isolated apply run.
- Set hook-invoked tasks to quiet unless their output is an intentional user-facing result.
- Do not duplicate hook commands in `scripts/mise.zsh`.
- Keep link cleanup scoped to an additive tracked historical path inventory, exclude mise runtime state, support dry runs, and resolve physical source containment before removal.

## Validation

- Syntax-check `scripts/install-mise.zsh` and `scripts/mise-env.zsh` without executing them.
- Run `tests/scripts/test_mise_bootstrap_lifecycle.zsh`.
- Run `tests/scripts/test_mise_config.zsh`.
- Preview both `work` and `personal` full bootstrap plans.
- Verify that a bootstrap error prevents later work.
- Run `mise run fix` after the focused tests pass.
