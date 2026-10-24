---
name: mise-bootstrap-modules
description: Use when adding, removing, splitting, or reviewing this repository's mise bootstrap modules, package and tool declarations, dotfiles, repositories, hooks, or environment fragments.
---

# Mise Bootstrap Modules

Use this skill for changes under `home/.config/mise/conf.d/`, `home/.config/mise/miserc.toml`, the module contract test, and module-specific behavior tests.

## Module boundaries

- Keep one `<name>.toml` file for each package, tool, or logical configuration boundary.
- Keep tightly coupled declarations in one module.
- Give each target one owner.
- Keep tool-owned runtime files outside tracked sources and module declarations.
- Keep post-install behavior in the owning module's `[bootstrap.hooks]` table.
- Use the existing `mise.toml` control plane to deploy every tracked module file.

Use these declaration types:

- Use `[bootstrap.packages]` for host packages.
- Use `[tools]` for versioned development tools.
- Use `[bootstrap.repos]` for Git repositories.
- Use `[dotfiles]` for user files that mise links, copies, templates, or edits.
- Use `[bootstrap.hooks]` for repeatable commands tied to a bootstrap phase.
- Define every dotfiles block with a source file instead of inline multiline content.

Read the [mise bootstrap reference](https://mise.jdx.dev/bootstrap.html), [machine modules reference](https://mise.jdx.dev/bootstrap/modules.html), and [dotfiles reference](https://mise.jdx.dev/dotfiles.html) before changing declaration semantics.

## Source and control-plane rules

- Keep global mise sources under `home/.config/mise/`.
- Use explicit `~/dev/personal/dot/home/...` sources for declarations loaded from the deployed global configuration.
- Keep `relative_symlinks = true` in the global mise configuration.
- Keep the module declaration, control-plane link, profile selection, and module contract case in the same change.
- Add a behavior-specific focused test only when the module has assertions beyond the shared declaration contract.
- Follow `mise-tasks`: make every file task under `home/.config/mise/tasks/` executable, and test its executable bit and discovery.
- If a file task installs a package manager with a shell-environment command, run that command after installation.
- Use `/opt/homebrew` as the Homebrew prefix. Do not add Intel `/usr/local` fallback paths.

## Environment selection

- Keep shared modules in files without an environment suffix.
- Name personal-only modules `<name>.personal.toml`.
- Keep `env_conf_d = true` in `miserc.toml`.
- Use `home/.config/mise/miserc.local.toml.tmpl` to select the persisted `work` or `personal` environment.
- Use `mise-bootstrap-profiles` for profile state, rendering, and cleanup behavior.

## Removal

- Change the persisted profile before previewing removal of a module.
- Keep the module declaration on disk until `mise bootstrap unapply <module>` completes.
- Preview `mise bootstrap unapply <module> --dry-run` before applying removal.
- Review package, repository, service, and Compose cleanup separately because module unapply does not remove every resource type.
- Remove the source only after its managed targets are no longer owned.

## Validation

- Add or update the matching case in `tests/scripts/test_mise_bootstrap_modules.zsh`.
- Add or update `tests/scripts/test_mise_bootstrap_<name>.zsh` only for module-specific behavior.
- Verify the declaration, control-plane link, profile selection, target ownership, and runtime exclusions.
- Run the module contract test and any behavior-specific test before aggregate checks.
- Run `mise run fix` after the module contract test and any behavior-specific test pass.
