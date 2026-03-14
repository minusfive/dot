---
name: pr-guidelines
description: Guidelines for pushing branches and creating pull requests. Use when asked to push changes or open a pull request in this macOS dotfiles project.
---

# Pull Request Guidelines

- **MUST NOT** skip hooks execution under any circumstances
- Complete [Commit Guidelines](../commit-guidelines/SKILL.md) (branch creation and commits) before proceeding

## 1: Push

- Push the branch to the remote repository
- Verify the push succeeded before opening a pull request

## 2: Pull Request

- Use the same Conventional Commits format for the pull request title as for commit messages (`<type>[(<scope>)][!]: <summary>`), summarizing all changes in the pull request
- The pull request body should include a brief summary of the changes and any relevant context or notes for the reviewer
- **MUST NOT** include commit messages in the pull request body — these are clear from the PR's commit history and will quickly become stale
- Reference any related issues or pull requests where relevant
- Request explicit approval before opening the pull request, never auto-open without user confirmation
