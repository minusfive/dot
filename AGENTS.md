# Repository Agent Rules

- Treat `home/` as the source tree for global files managed under `$HOME`.
- Keep repository-only guidance in this file or under `.agents/`.
- Use `mise-bootstrap-migration` when you migrate dotfiles, bootstrap resources, or GNU Stow ownership.
- Group `.config/mise/conf.d/` files by logical boundary.
- Wire new bootstrap phases into `scripts/mise.zsh` when `scripts/init.zsh --mise` must apply them.
- Keep tool-owned runtime files outside tracked sources and mise declarations.
- Split tests by bootstrap boundary and run the focused tests before the aggregate checks.
- Run `mise run check` after changing instructions or skills; it validates both the root and `home/` skill indexes.
- Update `README.md` in the same change when setup, layout, ownership, tooling, migration status, or user-facing workflows change. Load `readme-maintenance` for README decisions and edits.
- Preserve unrelated worktree changes.

## Skills

The skills below are available under `.agents/skills/`. **MUST NOT** preload any skill in this index. Load skills as needed when their description or use-when criteria match the task.

### Index

- `mise-bootstrap-migration` — Migrate repository-managed dotfiles and bootstrap resources between GNU Stow, scripts, and mise.
- `readme-maintenance` — Keep `README.md` current, educational, and accurate when repository behavior or structure changes.
- `code-review` — Guide automated code-review agents: focus on PR/commit diffs, pre-scan for CI/failing tests, skip generated/binary/very large files, and cap per-file token use to avoid wasted tokens.
