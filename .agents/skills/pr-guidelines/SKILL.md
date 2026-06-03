---
name: pr-guidelines
description: Push branches and open pull requests with correct title/body conventions. Use when preparing a branch for review, writing PR metadata, or opening a PR with linked issues.
---

# Pull Request Guidelines

- Complete `commit-guidelines` skill (including hook policy, branch creation, and commits) before proceeding

## 1: Push

- Push the branch to the remote repository
- Verify the push succeeded before opening a pull request

## 2: Pull Request

- PR title and message formatting **MUST** follow the same guidelines as commits
- The pull request body should include a brief summary of the changes and any relevant context or notes for the reviewer
- **MUST NOT** include commit messages in the pull request body — these are clear from the PR's commit history and will quickly become stale
- Reference any related issues or pull requests where relevant
- Request explicit approval before opening the pull request, never auto-open without user confirmation
