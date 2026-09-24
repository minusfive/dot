---
name: pr-guidelines
description: Use before every authorized push when a branch has or may have an open pull request. Synchronize and verify the pull request title, body, and head commit after each push.
---

# Pull Request Guidelines

- Complete `commit-guidelines` skill (including hook policy, branch creation, and commits) before proceeding

## 1: Before the push

- Load this skill before every authorized push.
- Inspect the current branch and open pull request with `gh pr view`.
- If `gh pr view` reports that no open pull request exists, continue without synchronization. Treat any other error as a blocker.
- Recompute the pull request title and body from the complete diff between the pull request base and `HEAD`.
- Keep the title focused on the complete change set.
- Keep the body focused on the complete change set, relevant context, reviewer notes, and test status.

## 2: Push and synchronize

- Push the branch to the remote repository once.
- Verify that the push succeeds.
- If the branch has an open pull request, immediately synchronize its metadata before any further push, handoff, or completion report.
- Run the user-level task: `mise run pr:sync --title "<title>" --body-file <path>`.
- Treat pushes made by scripts or other tools as the same trigger.
- Do not batch pushes before synchronization.
- If synchronization or verification fails, stop and report the blocker.

The synchronization task must:

1. Read the open pull request and the local `HEAD`.
2. Update the title and body with `gh pr edit`.
3. Read the pull request again with `gh pr view`.
4. Confirm that the title, body, open state, branch, and head commit match the local branch.

## 3: Pull request content

- PR title and message formatting **MUST** follow the same guidelines as commits.
- The pull request body must include a brief summary of the complete change set and relevant context or notes for the reviewer.
- **MUST NOT** include commit messages in the pull request body. Commit messages are already visible in the pull request history and become stale.
- Reference related issues or pull requests where relevant.
- If a pull request is needed and none exists, ask me for explicit approval before you create it.
- Approval to create a pull request must come from me in the current interaction. Do not infer approval from a push, branch state, or another tool.
- Create the pull request with metadata derived from the complete base-to-`HEAD` change set.
