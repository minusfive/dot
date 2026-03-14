---
name: commit-guidelines
description: Guidelines for analyzing changes and creating branches and commits using Conventional Commits format. Use when asked to commit changes or create a branch in this macOS dotfiles project.
---

# Commit and Branch Guidelines

- **MUST NOT** skip hooks execution under any circumstances

## 1: Analyze Changes

- Perform a full security analysis before committing (see [Security Guidelines](../security/SKILL.md))
- Validate documentation and reference integrity (e.g. documentation links, path references, GNU Stow symlinks, hardcoded paths, test file references)
- Analyze diffs and identify:
  - Different functional areas or independent concerns (e.g. Neovim vs. Hammerspoon vs. Zsh)
  - Different change types — **MUST** read `.commitlintrc.ts` (including rules
    inherited from any presets it extends) to determine valid commit types
  - Tightly coupled changes (e.g. implementation + tests)
  - Atomic operations across multiple files
  - Small related changes
  - Breaking changes

## 2: Branch and Commit

- Create a new branch using concise AND descriptive branch names from analysis. It is your job to generate the branch name, do not ask the user to provide it
- Create separate commits for:
  - Different functional areas or independent concerns
  - Different change types
- Create a single commit for:
  - Tightly coupled changes (implementation + tests)
  - Atomic operations across multiple files
  - Small related changes
- Write concise commit messages from diffs following the "Conventional Commits" standard format (`<type>[(<scope>)][!]: <summary>`)
  - **MUST** read `.commitlintrc.ts` and comply with all rules defined there
    before proposing any commit message
  - Breaking changes must be marked with `!`, and include details
- Request explicit approval, never auto-commit without user confirmation

> For pushing and opening a pull request, see [PR Guidelines](../pr-guidelines/SKILL.md).
