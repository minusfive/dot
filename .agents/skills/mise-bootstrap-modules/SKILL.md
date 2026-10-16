---
name: mise-bootstrap-modules
description: Use when adding, removing, splitting, or reviewing this repository's mise bootstrap modules, package and tool declarations, dotfiles, repositories, hooks, or profile module lists.
---

# Mise Bootstrap Modules

Use this skill for changes under `home/.config/mise/conf.d/`, `home/.config/mise/miserc.toml`, and the focused tests that cover those boundaries.

## Module boundaries

- Keep one `module.<name>.toml` file for each package, tool, or logical configuration boundary.
- Keep tightly coupled declarations in one module.
- Give each target one owner.
- Keep tool-owned runtime files outside tracked sources and module declarations.
- Keep post-install behavior in the owning module's `[bootstrap.hooks]` table.
- Use the existing `module.mise.toml` control plane to deploy every tracked module file.

Use these declaration types:

- Use `[bootstrap.packages]` for host packages.
- Use `[tools]` for versioned development tools.
- Use `[bootstrap.repos]` for Git repositories.
- Use `[dotfiles]` for user files that mise links, copies, templates, or edits.
- Use `[bootstrap.hooks]` for repeatable commands tied to a bootstrap phase.

Read the [mise bootstrap reference](https://mise.jdx.dev/bootstrap.html), [machine modules reference](https://mise.jdx.dev/bootstrap/modules.html), and [dotfiles reference](https://mise.jdx.dev/dotfiles.html) before changing declaration semantics.

## Source and control-plane rules

- Keep global mise sources under `home/.config/mise/`.
- Use explicit `~/dev/personal/dot/home/...` sources for declarations loaded from the deployed global configuration.
- Keep `relative_symlinks = true` in the global mise configuration.
- Keep the module declaration, control-plane link, profile selection, and focused test in the same change.

## Profile selection

- Keep shared modules in both profile lists.
- Keep personal-only modules in the `personal` list.
- Use Tera list spread in `miserc.toml` when both profiles share a common environment list.
- Keep module selection in the rendered `miserc.toml`.
- Use `mise-bootstrap-profiles` for profile state, rendering, and cleanup behavior.

## Removal

- Change the persisted profile before previewing removal of a module.
- Keep the module declaration on disk until `mise bootstrap unapply <module>` completes.
- Preview `mise bootstrap unapply <module> --dry-run` before applying removal.
- Review package, repository, service, and Compose cleanup separately because module unapply does not remove every resource type.
- Remove the source only after its managed targets are no longer owned.

## Validation

- Add or update `tests/scripts/test_mise_bootstrap_<name>.zsh` for each module boundary.
- Verify the declaration, control-plane link, profile selection, target ownership, and runtime exclusions.
- Run the focused module test before aggregate checks.
- Run `mise run fix` after the focused test passes.
