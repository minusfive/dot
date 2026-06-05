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

## Examples

- List docs directory: `gh api repos/jdx/mise/contents/docs`
- Read a file raw: `gh api repos/jdx/mise/contents/docs/tasks/file-tasks.md -H "Accept: application/vnd.github.raw+json"`
- View PR comments: `gh api repos/<owner>/<repo>/pulls/<number>/comments`

## Fallback

- If `gh` is not installed or not authenticated, report the exact blocker and next command needed.
- Do not silently switch to web fetch for GitHub operations.
