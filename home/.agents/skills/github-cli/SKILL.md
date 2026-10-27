---
name: github-cli
description: Use the `gh` CLI for pull requests, issues, workflow runs, releases, repository metadata, and file content on GitHub. Use when interacting with any GitHub resource from the terminal.
---

# GitHub CLI Rules

> [!IMPORTANT]
> All rules and guidelines in this document are **MANDATORY**

## Core Rule

- Use `gh` CLI for all GitHub interactions when `gh` is available.
- Do not use generic web fetching tools for GitHub URLs when the same operation can be done with `gh`.

## Required Usage

- Repository and file content: use `gh api`.
- Pull requests: use `gh pr` and `gh api`.
- Issues: use `gh issue` and `gh api`.
- Checks, runs, and releases: use `gh run`, `gh release`, and `gh api`.
- Authentication and context checks: use `gh auth status` and related `gh` commands.

## GitHub Project authentication

1. Before any GitHub Project operation, run `gh auth status --json hosts` and inspect the active account's `scopes`.
2. If the active token lacks the `project` scope, stop and ask me to run `gh auth refresh -s project`.
3. If the GitHub CLI reports that `read:project` is also required, include that scope in the refresh command: `gh auth refresh -s project,read:project`.
4. After I refresh the token, run the scope check again before continuing.

## Stacked Pull Requests

- Create a stack from existing pull requests with `mise run pr:stack -- <bottom-pr> <child-pr> ...`.
- Sync a GitHub-rebased PR branch with `mise run pr:stack-sync -- --pr-number <number>`.
- Use `gh stack` for local branch stacks: `gh stack init`, `gh stack add`, `gh stack push`, and `gh stack submit`.
- Inspect and update a stack with `gh stack view`, `gh stack sync`, `gh stack rebase`, and `gh stack merge`.
- Read [About stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs) and [Stacked pull request CLI commands](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands) when the workflow changes.
- Follow `pr-guidelines` for complete-diff metadata and PR synchronization.

## Examples

- List docs directory: `gh api repos/jdx/mise/contents/docs`
- Read a file raw: `gh api repos/jdx/mise/contents/docs/tasks/file-tasks.md -H "Accept: application/vnd.github.raw+json"`
- View PR comments: `gh api repos/<owner>/<repo>/pulls/<number>/comments`

## Fallback

- If `gh` is not installed or not authenticated, report the exact blocker and next command needed.
- Do not silently switch to web fetch for GitHub operations.
