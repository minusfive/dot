---
name: mise-bootstrap-migration
description: Use when migrating global dotfiles, AI instructions, tool configuration, or bootstrap resources from GNU Stow or scripts to mise in this repository.
---

# Mise Bootstrap Migration

Use this skill when you move global configuration into the `home/` source tree or change a bootstrap boundary.

## Security and approval gate

- Perform a full security assessment before you edit a migration.
- Identify files that can contain secrets, tokens, credentials, databases, private keys, personal hosts, or tool runtime state.
- Keep sensitive or tool-owned files outside tracked sources unless the repository already owns them safely.
- Use the `security` skill and the repository's leak checks during the assessment.
- Present the viable migration options, their ownership effects, and their risks.
- Wait for my explicit approval before you change files or apply a migration.
- Stop when I do not approve an option or when the assessment finds an unresolved sensitive-data risk.

## Scope

- Keep this skill repository-local. Do not move it into `home/.agents/skills/`.
- Do not add repo-only skills to the global `home/AGENTS.md` skill index.
- Leave unrelated worktree changes untouched.
- Read the current bootstrap configuration and tests before you edit them.

## Source layout

- Put global file sources under `home/`.
- Mirror each target path below `home/`.
- Keep repository-only files outside `home/`.
- Keep tool-owned runtime files outside tracked sources.
- Keep secrets, tokens, databases, lock files, and dependencies outside tracked sources unless the repository already owns them.

## Mise boundaries

- Group files in `.config/mise/conf.d/` by logical boundary.
- Use a tool or related feature as the boundary.
- Use names such as `bootstrap-gh.toml` and `bootstrap-ai.toml`.
- Keep each boundary small enough to test on its own.
- Use `[dotfiles]` for user files that mise links, copies, templates, tracks, or removes.
- Use `symlink-each` when a target directory also contains files owned by another tool.
- Use `[bootstrap.files]` for bootstrap-created or rendered files.
- Use `[bootstrap.directories]` for directory state such as permissions.
- Give each target one owner. Do not overlap mise and GNU Stow declarations.

## Initialization wiring

- Add the new bootstrap phase to `scripts/mise.zsh` when the resource must apply through `scripts/init.zsh --mise`.
- Preserve the existing phase order unless the resource has a dependency that requires a different position.
- Add a confirmation step that matches the neighboring phases.
- Update the skip message when the new phase changes the scope of the initialization flow.
- Apply the complete mise bootstrap with `./scripts/init.zsh --mise`.
- Use direct `mise bootstrap` commands only for targeted status or dry-run validation.
- Apply remaining GNU Stow configuration with `./scripts/init.zsh --link`.

## Stow transitions

- Inspect `.stowrc` and `.stow-local-ignore` before changing ownership.
- Remove or ignore the old Stow source only after the new mise source exists.
- Preserve local files that the tool owns.
- Use `stow -nvR .` before and after the transition for non-mutating ownership validation.
- Stop when the dry-run proposes a migrated target or a conflicting local file.

## Tests

- Split tests by `.config/mise/conf.d/` boundary.
- Keep general initialization and profile checks in a separate test.
- Test source paths, declaration modes, target ownership, and exclusion boundaries.
- Test that tool-owned runtime files are not declared.
- Test the initialization command order and the new phase.
- Use reusable helpers for repository-root setup and failure handling.

## Documentation

- Describe the layout and ownership model in `README.md`.
- Explain how the source tree, mise declarations, and legacy Stow surface relate.
- Keep README content descriptive. Put commands and operational rules in scripts or skills.
- Document migration status with a short informational note when both systems remain active.

## Validation

Run the focused tests for each changed boundary. Then run:

- Validate the repo-only skill frontmatter and Markdown.
- `mise run check`
- `mise bootstrap dotfiles status`
- `mise bootstrap dotfiles apply --dry-run`
- `stow -nvR .`

Verify README links and inspect the complete diff before you commit.

## Critique

- Check that every migrated target has one owner.
- Check that the init flow applies every new resource.
- Check that tool-owned runtime files remain unmanaged.
- Check that tests cover each logical bootstrap boundary.
- Check that README prose explains the architecture without copying operational instructions.
