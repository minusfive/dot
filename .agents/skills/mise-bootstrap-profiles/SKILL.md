---
name: mise-bootstrap-profiles
description: Use when changing work and personal mise profiles, persisted profile state, profile-specific modules, rendered miserc selection, or module cleanup in this repository.
---

# Mise Bootstrap Profiles

Use this skill when a change affects profile selection or profile-specific machine resources.

## State ownership

- Treat `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile` as the canonical bootstrap source.
- Let `scripts/init.zsh` read and write that state through the existing profile helpers.
- Export the selected value as `DOT_PROFILE` for the current initialization run.
- Treat the macOS defaults value `hs.minusfive.profile` as a persistent mirror for Hammerspoon and other macOS consumers.
- Treat `hs.minusfive.profile.is_work` and `hs.minusfive.profile.is_personal` as derived mirror values.
- Let Hammerspoon's `ProfileState Spoon` read the state file and synchronize these values when Hammerspoon starts.
- Keep the state file authoritative for shell and mise bootstrap operations.
- Add an explicit, tested synchronization path before treating the macOS mirror as an independent source.
- Keep the profile template in `home/.config/mise/miserc.toml`.

Read the [mise machine modules reference](https://mise.jdx.dev/bootstrap/modules.html) and [mise template reference](https://mise.jdx.dev/templates.html#miserc-template-support) before changing profile behavior.

## Selection rules

- Keep `work` as the safe default when no profile is stored.
- Accept only `work` and `personal` in the initializer.
- Keep the shared module set in both profile branches.
- Add a personal-only module only to the `personal` branch.
- Preserve the existing repository context while mise renders the profile.
- Keep profile selection in the rendered `miserc.toml`.
- Do not introduce a second profile selector that can omit shared modules.

## Profile changes

1. Update the module declaration.
2. Update both profile lists, or only the `personal` list for a personal-only resource.
3. Update the matching focused test.
4. Preview both profiles with `mise bootstrap --dry-run`.
5. Verify that personal-only resources do not appear in the `work` profile.
6. Run the focused test and `mise run fix`.

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

- the persisted profile path and `DOT_PROFILE` handoff;
- shared module selection in both branches;
- personal-only module selection;
- full-profile dry-run output; and
- cleanup or ownership changes when a profile loses a module.
