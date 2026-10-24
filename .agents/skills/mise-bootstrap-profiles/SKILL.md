---
name: mise-bootstrap-profiles
description: Use when changing work and personal mise profiles, persisted profile state, profile-specific modules, rendered miserc selection, or module cleanup in this repository.
---

# Mise Bootstrap Profiles

Use this skill when a change affects profile selection or profile-specific machine resources.

## State ownership

- Let `vars.resolved_profile` resolve explicit environment selection first, then the profile state file, then `work`.
- Let the control-plane dotfiles render `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` and `miserc.local.toml` from that value.
- Let `home/.config/mise/tasks/bootstrap/pre-packages.zsh` validate and confirm the selected profile before package bootstrap.
- Export the selected value as `DOT_PROFILE` for existing consumers during the current initialization run.
- Treat the macOS defaults value `hs.minusfive.profile` as a persistent mirror for Hammerspoon and other macOS consumers.
- Treat `hs.minusfive.profile.is_work` and `hs.minusfive.profile.is_personal` as derived mirror values.
- Let Hammerspoon's `ProfileState Spoon` read the state file and synchronize these values when Hammerspoon starts.
- Treat the rendered profile state file as the shell and `mise` bootstrap input.
- Keep the macOS profile value as a mirror of the rendered state file.
- Keep the selector template in `home/.config/mise/miserc.local.toml.tmpl`.

Read the [mise machine modules reference](https://mise.jdx.dev/bootstrap/modules.html) and [mise template reference](https://mise.jdx.dev/templates.html#miserc-template-support) before changing profile behavior.

## Selection rules

- Keep `work` as the safe default when no profile is stored.
- Accept only `work` and `personal` in the bootstrap task.
- Keep shared fragments without an environment suffix.
- Add a `.personal.toml` suffix only to personal-only fragments.
- Preserve the existing repository context while mise renders the profile.
- Keep environment selection in the generated `miserc.local.toml`.
- Keep the resolved profile fallback in `home/.config/mise/config.toml` when the generated selector is absent.
- Do not introduce a second profile selector that can omit shared modules.

## Profile changes

1. Update the module declaration.
2. Update the shared fragment, or the personal fragment for a personal-only resource.
3. Update the matching case in `tests/scripts/test_mise_bootstrap_modules.zsh`.
4. Update a behavior-specific focused test when profile behavior affects ownership or cleanup.
5. Preview both profiles with `mise bootstrap --dry-run`.
6. Verify that personal-only resources do not appear in the `work` profile.
7. Run the module contract test, any behavior-specific test, and `mise run fix`.

Use the repository's established context for each preview.

## Removing profile resources

- Select the new persisted profile before previewing cleanup.
- Keep removed module declarations available while mise plans their cleanup.
- Preview `mise bootstrap unapply <module> --dry-run`.
- Apply the unapply only after the plan names the intended targets.
- Run package pruning separately when a removed module declared packages.
- Verify the remaining profile still renders and loads its shared modules.

## Tests

Profile tests must cover:

- the persisted profile path and generated selector;
- shared fragment selection in both environments;
- personal-only fragment selection;
- full-profile dry-run output; and
- cleanup or ownership changes when a profile loses a module.
