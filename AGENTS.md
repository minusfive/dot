# Repository Agent Rules

- Treat `home/` as the source tree for global files managed under `$HOME`.
- Keep repository-only guidance in this file or under `.agents/`.
- Use `mise-bootstrap-migration` when you migrate dotfiles, bootstrap resources, or GNU Stow ownership.
- Group `.config/mise/conf.d/` files by logical boundary.
- Wire new bootstrap phases into `scripts/mise.zsh` when `scripts/init.zsh --mise` must apply them.
- Keep tool-owned runtime files outside tracked sources and mise declarations.
- Split tests by bootstrap boundary and run the focused tests before the aggregate checks.
- Preserve unrelated worktree changes.

## Skills

### Index

- `mise-bootstrap-migration` — Migrate repository-managed dotfiles and bootstrap resources between GNU Stow, scripts, and mise.
