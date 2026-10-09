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

## Planning and handoff

- Make the persisted plan the execution source of truth.
- Inline every implementation-critical decision before execution starts:
  source paths, target paths, ownership modes, runtime exclusions, code
  coupling, focused tests, validation commands, rollback, and disposition.
- Remove completed discovery and decision stories from the executable plan.
  Leave only approved mutation and validation stories.
- Keep the exact plan path in the execution handoff. Do not make execution
  rediscover scope from a separate research matrix.
- Record research artifacts as supporting evidence, not as hidden prerequisites
  for implementation.

## Source layout

- Put global file sources under `home/`.
- Mirror each target path below `home/`.
- Keep repository-only files outside `home/`.
- Keep tool-owned runtime files outside tracked sources.
- Keep secrets, tokens, databases, lock files, and dependencies outside tracked sources unless the repository already owns them.

## Mise boundaries

- Group source files in `home/.config/mise/conf.d/` by logical boundary.
- Use a tool or related feature as the boundary.
- Use names such as `bootstrap-gh.toml` and `bootstrap-ai.toml`.
- Keep each boundary small enough to test on its own.
- Use `[dotfiles]` for user files that mise links or symlink-each manages.
- Use `symlink` for a complete managed target and `symlink-each` when a target
  directory must coexist with application-owned files.
- Keep migrated files symlinked so live changes remain visible in the working
  tree for user review.
- Set the global `dotfiles.relative_symlinks` setting to `true` before applying
  migrated symlink declarations.
- Inspect the actual target path before choosing a mode. A whole-directory Stow
  symlink can make a per-file mise declaration write through to the repository
  source.
- Use `[bootstrap.files]` for bootstrap-created or rendered files.
- Use `[bootstrap.directories]` for directory state such as permissions.
- Give each target one owner. Do not overlap mise and GNU Stow declarations.

## Remote resources

- Use `[bootstrap.repos]` for Git repositories.
- Use `[dotfiles]` for local user-file sources.
- Use `[bootstrap.files]` for local system-file content.
- Use `[dotfiles]` for user files that belong to the repository, including
  files that currently use `[bootstrap.files]`.
- Keep `[bootstrap.files]` for paths that need a system owner, group,
  permissions, privileged writes, service notifications, or system scope.
- Keep `[bootstrap.directories]` when directory state such as owner, group, or
  mode is the resource being managed.
- Treat arbitrary `curl` or `wget` downloads as custom network code.
- Prefer reviewed, reproducible sources over mutable remote downloads in an
  initialization path.

## Initialization wiring

- Inspect `scripts/mise.zsh` before adding a phase.
- Inspect `scripts/init.zsh`, `scripts/mise.zsh`, and every phase script that
  the migration changes.
- Reuse the existing mise bootstrap part when a new `conf.d` declaration is
  already covered by that part.
- Add a new phase only when the resource needs distinct ordering, confirmation,
  or failure handling.
- Keep phase invocation, ordering, confirmations, skip messages, and related
  comments consistent with the changed resource.
- Record a no-change decision in the plan when existing initialization wiring
  already covers the resource.
- Preserve the existing phase order unless the resource has a dependency that requires a different position.
- Add a confirmation step that matches the neighboring phases.
- Update the skip message when the new phase changes the scope of the initialization flow.
- Apply the complete mise bootstrap with `./scripts/init.zsh --mise`.
- Use direct `mise bootstrap` commands only for targeted status or dry-run validation.
- Apply remaining GNU Stow configuration with `./scripts/init.zsh --link`.

## Stow transitions

- Inspect `.stowrc` and `.stow-local-ignore` before changing ownership.
- Remove or ignore the old Stow source only after the new mise source exists.
- Verify and detach an old parent-directory symlink before applying per-file
  mise entries below that directory.
- Preserve local files that the tool owns.
- Use `stow -nvR .` before and after the transition for non-mutating ownership validation.
- Treat ignored files as unmanaged only after the Stow dry run confirms that
  Stow ignores them. Git ignore rules alone do not protect physical files.
- Do not use `stow --adopt` for secrets or tool-owned runtime state.
- Stop when the dry-run proposes a migrated target or a conflicting local file.

## Tool removal

- Treat tool removal as an ownership transition, not only a package change.
- Keep the existing mise declaration while you run
  `mise bootstrap dotfiles unapply --dry-run`.
- Apply the unapply only after its output names the intended managed targets.
- Remove the declaration and source only after `mise dot unapply` completes.
- Use `mode = "absent"` when the target must be removed on every machine.
- Apply the absent declaration, then check `mise dot status` and a dry run.
- Remove stale `symlink-each` sources and apply again so mise removes their
  recorded links.
- Run `stow -nvR .` after cleanup and stop if a removed tool target remains.

## Machine modules

- Keep modules per package or logical boundary in `config.<module>.toml`
  environment files. Do not combine unrelated resources into one machine-role
  module.
- Keep one tracked `miserc.toml` Tera template with profile conditionals.
  Render the module list from `env.DOT_PROFILE`.
- Keep the active `~/.config/mise/miserc.toml` linked to that tracked source
  through the repository's global mise control-plane boundary.
- Keep optional `.local.toml` overrides out of version control through Git's
  global excludes file, normally `$XDG_CONFIG_HOME/git/ignore`; do not rely
  only on repository or Stow ignore patterns.
- Keep module declarations on disk until `mise bootstrap unapply <module>`
  finishes its cleanup.
- Change the persisted profile before previewing unapply for removed modules.
- When a profile change removes modules, unapply those modules after selecting
  the new profile and before the next bootstrap apply.
- Review package, repository, Compose, and service cleanup separately because
  module unapply does not remove every resource type.
- Keep profile-specific module lists in the repository template. Keep the
  persisted profile value outside the repository.
- Use the [mise machine modules documentation](https://mise.jdx.dev/bootstrap/modules.html)
  and [configuration file precedence](https://mise.jdx.dev/configuration.html)
  as the source of truth for module selection and cleanup.
- Use the [mise `miserc` template documentation](https://mise.jdx.dev/templates.html#miserc-template-support)
  as the source of truth for profile conditionals.

## Tests

- Split tests by `home/.config/mise/conf.d/` boundary.
- Keep general initialization and profile checks in a separate test.
- Test source paths, declaration modes, target ownership, and exclusion boundaries.
- Test that tool-owned runtime files are not declared.
- Test initialization command order only when the change affects that order.
- Test that obsolete download blocks and stale ownership declarations are absent.
- Use reusable helpers for repository-root setup and failure handling.

## Documentation

- Load `readme-maintenance` when migration changes affect `README.md`.
- Provide that skill with the migration-specific facts about source layout, ownership, and status.
- Keep migration procedures and operational rules in this skill or the relevant scripts.
- Document migration status with a short informational note when both systems remain active.

## Validation

Run the focused tests for each changed boundary. Then run:

- Validate the repo-only skill frontmatter and Markdown.
- `mise run check`
- `mise bootstrap dotfiles status`
- `mise bootstrap dotfiles apply --dry-run`
- `stow -nvR .`

- Run a pre-transition dry run and preserve its result.
- Verify the ownership cutover before applying the new mise boundary.
- Run a post-transition dry run and the boundary-specific rollback check.
- Verify README links and inspect the complete diff before you commit.

## Critique

- Check that every migrated target has one owner.
- Check that the init flow applies every new resource.
- Check that tool-owned runtime files remain unmanaged.
- Check that tests cover each logical bootstrap boundary.
- Check that README prose explains the architecture without copying operational instructions.
