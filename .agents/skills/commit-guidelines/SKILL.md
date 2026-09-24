---
name: commit-guidelines
description: Create branches and commits from local diffs with correct commit message conventions. Use when asked to branch, split commits, write commit messages, or apply commitlint/Conventional Commits rules.
---

# Commit and Branch Guidelines

Follow the canonical hook-bypass policy in `AGENTS.md` (Tool Usage). For git specifically, this means commands such as `git commit --no-verify`, `git merge --no-verify`, and `git push --no-verify` are not used; failing hooks must be fixed at the root cause.

## Analyze Changes

- Perform a comprehensive review of all the changes
- Perform a full security analysis before committing (see `security` skill)
- Validate documentation and reference integrity (e.g. documentation links, path references, hardcoded paths, test file references)
- Analyze diffs and identify:
  - Different functional areas or independent concerns
  - Different change types
  - Tightly coupled changes (e.g. implementation + tests)
  - Atomic operations across multiple files
  - Small related changes
  - Breaking changes

## Branch

- Inspect the current worktree branch before you create or switch branches.
- If the current worktree is on a non-main branch, keep commits and pushes on that branch.
- Do not create or switch branches from a non-main worktree unless I explicitly ask you to do so.
- If the current worktree is on `main` or is detached, create a concise and descriptive branch unless I explicitly ask you to use another branch.

## Commit

- **MUST** determine and follow commit title and message constraints before drafting messages:
  - Check for commitlint configuration in this order: `commitlint.config.*`, `.commitlintrc*`, then `package.json` `commitlint` section
  - If commitlint config exists, follow its rules (including inherited presets)
  - If no commitlint config exists, use Conventional Commits (`<type>[(<scope>)][!]: <summary>`)
- Create separate commits for:
  - Different functional areas or independent concerns
  - Different change types
- Create a single commit for:
  - Tightly coupled changes (implementation + tests)
  - Atomic operations across multiple files
  - Small related changes
- Write concise commit messages from diffs using discovered commitlint rules when available, otherwise Conventional Commits format
  - Breaking changes should be clearly marked and include details
- Request explicit approval, never auto-commit without user confirmation
- If hooks fail, fix the underlying issues and retry; do not bypass hooks

## Pull Request

- For pushing and opening a pull request, see `pr-guidelines` skill.
