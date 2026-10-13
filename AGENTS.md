# Repository Agent Rules

- Treat `home/` as the source tree for global files managed under `$HOME`.
- Keep repository-only guidance in this file or under `.agents/`.
- This repository stores global skill sources under `home/.agents/skills`; pass `--skills-path home/.agents/skills` to the global `ai:skills:evals:*` tasks.
- Keep repository-local instruction files and task names distinct from global entrypoints.
- Use `mise-bootstrap-migration` when you migrate dotfiles or bootstrap resources to mise.
- Group `home/.config/mise/conf.d/` files by logical boundary.
- Group tightly coupled declarations in one `module.<name>.toml` file.
- Use the profile lists in `home/.config/mise/miserc.toml` to select modules for each environment. Keep profile-specific modules out of profiles that should not load them.
- When you add or move package declarations between `home/.config/mise/conf.d/` modules, inspect `home/.config/mise/miserc.toml`. Update the `work` and `personal` module lists when selection changes, keep personal-only packages out of `work`, and cover the boundary in focused package tests.
- Wire new bootstrap phases into `scripts/mise.zsh` when `scripts/init.zsh --mise` must apply them.
- Keep tool-owned runtime files outside tracked sources and mise declarations.
- Split tests by bootstrap boundary and run the focused tests before the aggregate checks.
- Name each focused package test `test_mise_bootstrap_<name>.zsh` to match its corresponding `module.<name>.toml`. Keep each package assertion in that test; do not aggregate package-module assertions in a shared test.
- Run `mise run check` after changing instructions or skills; it validates both the root and `home/` skill indexes.
- Update `README.md` in the same change when setup, layout, ownership, tooling, migration status, or user-facing workflows change. Load `readme-maintenance` for README decisions and edits.
- Preserve unrelated worktree changes.

## Skills

The skills below are available under `.agents/skills/`. **MUST NOT** preload any skill in this index. Load skills as needed when their description or use-when criteria match the task.

### Index

- `mise-bootstrap-migration` — Migrate repository-managed dotfiles and bootstrap resources to mise.
- `readme-maintenance` — Keep `README.md` current, educational, and accurate when repository behavior or structure changes.
