# Repository Agent Rules

- Treat `home/` as the source tree for global files managed under `$HOME`.
- Keep repository-only guidance in this file or under `.agents/`.
- This repository stores global skill sources under `home/.agents/skills`; pass `--skills-path home/.agents/skills` to the global `ai:skills:evals:*` tasks.
- Keep repository-local instruction files and task names distinct from global entrypoints.
- Group `home/.config/mise/conf.d/` files by logical boundary.
- Group tightly coupled declarations in one `module.<name>.toml` file.
- Use the profile lists in `home/.config/mise/miserc.toml` to select modules for each environment. Keep profile-specific modules out of profiles that should not load them.
- Keep module names in each `home/.config/mise/miserc.toml` profile list alphabetized.
- When you add or move package declarations between `home/.config/mise/conf.d/` modules, inspect `home/.config/mise/miserc.toml`. Update the `work` and `personal` module lists when selection changes, keep personal-only packages out of `work`, and cover the boundary in focused package tests.
- Keep the full bootstrap lifecycle in `scripts/tasks/system/bootstrap.zsh`; keep `scripts/init.zsh` limited to mise acquisition and compatibility forwarding.
- Keep tool-owned runtime files outside tracked sources and mise declarations.
- Keep each `home/.config/mise/conf.d/module.<name>.toml` boundary in its own `tests/scripts/test_mise_bootstrap_<name>.zsh`. Do not aggregate assertions for multiple modules in one test.
- Run focused module tests before the aggregate checks.
- Run `mise run fix` after changing instructions or skills; it applies configured autofixes and reports only unfixable failures, including root and `home/` skill-index validation.
- Update `README.md` in the same change when setup, layout, ownership, tooling, migration status, or user-facing workflows change. Load `readme-maintenance` for README decisions and edits.
- Before every commit, review the complete diff with the user and complete a fresh critique pass.
- Preserve unrelated worktree changes.

## Skills

The skills below are available under `.agents/skills/`. **MUST NOT** preload any skill in this index. Load skills as needed when their description or use-when criteria match the task.

### Index

- `mise-bootstrap-lifecycle` — Maintain the full mise initialization lifecycle, hooks, confirmations, and failure behavior.
- `mise-bootstrap-modules` — Maintain mise module boundaries, declarations, control-plane links, and profile selection.
- `mise-bootstrap-zsh` — Maintain Zsh startup zones, module-owned shell blocks, path precedence, and related bootstrap tests.
- `mise-bootstrap-profiles` — Maintain work and personal profile state, rendering, and module cleanup.
- `mise-bootstrap-testing` — Maintain focused tests for mise modules, profiles, lifecycle hooks, and ownership.
- `readme-maintenance` — Keep `README.md` current, educational, and accurate when repository behavior or structure changes.
