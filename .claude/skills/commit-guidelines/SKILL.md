---
name: commit-guidelines
description: Guidelines for creating commits, branches, and pull requests using Conventional Commits format. Use when asked to commit changes, create a branch, or open a pull request in this macOS dotfiles project.
---

# Commit, Branch, and Pull Request Guidelines

When asked to commit changes (or just "commit"):

- Use all changes in the current repository if unspecified
- **MUST** execute each step below in order.
  - Complete each step before proceeding to the next.
  - Each step **MUST** be performed as its own independent task plan, following [Task Planning](../agent-interaction/SKILL.md#task-planning) guidelines.
  - The step title **MUST** be used as the Task Plan title.
- **MUST NOT** offer to execute a step / task plan until the previous one is completed and approved
- **DO NOT** offer to run tests or linters
- **DO NOT** skip hooks execution under any circumstances

## 1: Analyze Changes

- Perform a full security analysis before committing (see [Security Guidelines](../security/SKILL.md))
- Validate documentation and reference integrity (e.g. documentation links, path references, GNU Stow symlinks, hardcoded paths, test file references)
- Analyze diffs and identify:
  - Different functional areas or independent concerns (e.g. Neovim vs. Hammerspoon vs. Zsh)
  - Different change types:
    - `feat`: New feature or enhancement
    - `fix`: Bug fix
    - `docs`: Documentation changes
    - `style`: Code style changes (e.g. formatting, missing semicolons, etc.)
    - `refactor`: Code changes that neither fix bugs nor add features
    - `perf`: Performance improvements
    - `test`: Adding or modifying tests
    - `build`: Build system or external dependency changes
    - `ci`: CI/CD configuration changes
    - `chore`: Maintenance tasks, dependency updates
    - `revert`: Reverting previous commits
    - `config`: Configuration file changes
    - `security`: Security-related fixes or improvements
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
  - **MUST NOT** exceed 50 characters on the commit message subject line
  - Details may be added after a blank line as a markdown list, maximum 72 characters per line.
  - Breaking changes must be marked with `!`, and include details
- Request explicit approval, never auto-commit without user confirmation

## 3: Pull Request

- Push branch to remote repository
- Use the same commit message format for pull request titles, summarizing all changes in the pull request
