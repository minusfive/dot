---
name: pr-guidelines
description: Use before every authorized push when a branch has or may have an open pull request. Synchronize and verify the pull request title, body, and head commit after each push.
---

# Pull Request Guidelines

- Complete `commit-guidelines` skill (including hook policy, branch creation, and commits) before proceeding

## 1: Derive the complete change set

- Load this skill before every authorized push.
- Inspect the current branch and open pull request with `gh pr view`.
- If `gh pr view` reports that no open pull request exists, continue without synchronization. Treat any other error as a blocker.
- Resolve the pull request base branch and commit from the hosting service.
- Build a change-set manifest from every path in the complete base-to-`HEAD` diff.
  - For an existing pull request, run `gh pr diff <number> --name-only` and sort the paths.
  - Before creating a pull request, run `git diff --name-only <base>...HEAD` and sort the paths.
- Inspect every changed path and the relevant patch before drafting the title or body.
- Group all changed paths into their functional areas. Use those areas to draft the title and body.
- Keep the title focused on the complete change set.
- Treat the pull request title as a commit header. Validate it with the repository's commitlint rules before synchronization.
- If the existing title fails validation, replace it with a compliant title derived from the complete change set.
- Keep the body focused on the complete change set, relevant context, reviewer notes, and test status.
- Do not use `gh pr create --fill`, `--fill-first`, or `--fill-verbose` for pull request metadata.
- Do not use the latest commit, the latest commit message, or a commit list as a substitute for the complete diff.

## 2: Push and synchronize

- Push the branch to the remote repository once.
- Verify that the push succeeds.
- If the branch has an open pull request, immediately synchronize its metadata before any further push, handoff, or completion report.
- Save the complete changed-path manifest to a temporary file.
- Run the user-level task: `mise run pr:sync --title "<title>" --body-file <path> --change-set-file <manifest>`.
- Treat pushes made by scripts or other tools as the same trigger.
- Do not batch pushes before synchronization.
- If synchronization or verification fails, stop and report the blocker.

The synchronization task must:

1. Read the open pull request and the local `HEAD`.
2. Read the complete server-side changed-path list with `gh pr diff --name-only`.
3. Confirm that the manifest matches the complete changed-path list.
4. Update the title and body with `gh pr edit`.
5. Read the pull request and changed-path list again.
6. Confirm that the title, body, open state, branch, head commit, and change-set manifest match the local branch and requested metadata.

## 3: Pull request content

- PR title and message formatting **MUST** follow the same guidelines as commits.
- Run the repository's configured commitlint command against the proposed title before running `pr:sync`.
- The pull request body must include a brief summary of the complete change set and relevant context or notes for the reviewer.
- **MUST NOT** include commit messages in the pull request body. Commit messages are already visible in the pull request history and become stale.
- Reference related issues or pull requests where relevant.
- If a pull request is needed and none exists, ask me for explicit approval before you create it.
- Approval to create a pull request must come from me in the current interaction. Do not infer approval from a push, branch state, or another tool.
- Create the pull request with metadata derived from the complete base-to-`HEAD` change set, then run `pr:sync` with the manifest after creation.
