# Repository Agent Rules

- Treat `home/` as the source tree for global files managed under `$HOME`.
- Keep repository-only guidance in this file or under `.agents/`.
- This repository stores global skill sources under `home/.agents/skills`; pass `--skills-path home/.agents/skills` to the global `ai:skills:evals:*` tasks.
- Keep repository-local instruction files and task names distinct from global entrypoints.
- Group `home/.config/mise/conf.d/` files by logical boundary.
- Group tightly coupled declarations in one `<name>.toml` file.
- Use native `mise` environment fragments to select modules. Keep personal fragments out of the `work` environment.
- When you add or move package declarations between `home/.config/mise/conf.d/` modules, inspect `home/.config/mise/conf.d/mise.toml`. Update the shared or personal fragment when selection changes, keep personal-only packages out of `work`, and update `tests/scripts/test_mise_bootstrap_modules.zsh`.
- Keep the full bootstrap lifecycle in `scripts/tasks/system/bootstrap.zsh`; keep `scripts/install-mise.zsh` limited to mise acquisition and printing the canonical task command.
- Keep task metadata and usage specifications with their executable file tasks.
- Keep tool-owned runtime files outside tracked sources and mise declarations.
- Keep declaration-only package, tool, and profile assertions in `tests/scripts/test_mise_bootstrap_modules.zsh`. Add a separate `tests/scripts/test_mise_bootstrap_<name>.zsh` file only for module-specific behavior.
- Create test fixtures with `mktemp` under `${TMPDIR:-/tmp}`. Keep temporary fixture data outside the repository tree.
- Run the module contract test and any behavior-specific module tests before aggregate checks.
- Run `mise run fix` after changing instructions or skills; it applies configured autofixes and reports only unfixable failures, including root and `home/` skill-index validation.
- Update `README.md` in the same change when setup, layout, ownership, tooling, migration status, or user-facing workflows change. Load `readme-maintenance` for README decisions and edits.
- Use one canonical executable entrypoint for each script. Do not retain compatibility wrappers unless the request explicitly requires them.
- Before every commit, review the complete diff with the user and complete a fresh critique pass.
- Preserve unrelated worktree changes.

## Skills

The skills below are available under `.agents/skills/`. **MUST NOT** preload any skill in this index. Load skills as needed when their description or use-when criteria match the task.

### Index

- `mise-bootstrap-lifecycle` — Maintain the full mise initialization lifecycle, hooks, confirmations, and failure behavior.
- `mise-bootstrap-modules` — Maintain mise module boundaries, declarations, control-plane links, and profile selection.
- `mise-bootstrap-zsh` — Maintain Zsh startup zones, module-owned shell blocks, path precedence, and related bootstrap tests.
- `mise-bootstrap-profiles` — Maintain work and personal profile state, rendering, and module cleanup.
- `mise-bootstrap-testing` — Maintain module contract tests and focused behavior tests for mise bootstrap profiles, hooks, and ownership.
- `readme-maintenance` — Keep `README.md` current, educational, and accurate when repository behavior or structure changes.
