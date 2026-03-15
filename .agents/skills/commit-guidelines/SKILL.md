---
name: commit-guidelines
description: Guidelines for analyzing changes and creating branches and commits with project-aware commit message rules.
---

# Commit and Branch Guidelines

- **MUST NOT** skip hooks execution under any circumstances

## 1: Analyze Changes

- Perform a full security analysis before committing (see `security` skill)
- Validate documentation and reference integrity (e.g. documentation links, path references, hardcoded paths, test file references)
- Analyze diffs and identify:
  - Different functional areas or independent concerns
  - Different change types
  - Tightly coupled changes (e.g. implementation + tests)
  - Atomic operations across multiple files
  - Small related changes
  - Breaking changes
- Determine commit message constraints before drafting messages:
  - Check for commitlint configuration in this order: `commitlint.config.*`, `.commitlintrc*`, then `package.json` `commitlint` section
  - If commitlint config exists, follow its rules (including inherited presets)
  - If no commitlint config exists, use Conventional Commits (`<type>[(<scope>)][!]: <summary>`)

## 2: Branch and Commit

- Create a new branch using concise AND descriptive branch names from analysis. It is your job to generate the branch name, do not ask the user to provide it
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

> For pushing and opening a pull request, see `pr-guidelines` skill.
