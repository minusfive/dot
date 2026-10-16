---
name: pr-orchestration
description: Orchestrate multi-issue GitHub delivery with durable issue plans, independent worktrees, separate PRs, isolated dummy-tree tests, critique gates, review watching, and manual merge handoff. Use when a request spans multiple issues or asks for parallel PR execution.
---

# Pull Request Orchestration

Use this skill for multi-issue work that needs separate branches, worktrees, pull requests, review cycles, or manual merge handoff.

## Start with durable plans

1. Load `planning` before drafting or refining a plan.
2. Defer plan research, decision resolution, story fields, research matrices, and planning critique to `planning`.
3. Treat each issue description as the canonical plan when I identify issues as the plan source.
4. Refine each issue description before implementation.
5. Use one independent planning subagent per issue.
6. Use an independent critique subagent for every proposed plan update before submitting it to GitHub.
7. Record plan updates and critique outcomes in the issue. Keep the issue description as the maintained plan.

## Build independent lanes

1. Build a dependency graph from the issue plans.
2. Create one branch and one worktree per issue.
3. Keep each worktree independent. Do not share mutable source files between lanes.
4. Start independent implementation agents in parallel.
5. Keep shared-file rebases or merges serialized.
6. Do not use one PR for multiple issue plans unless I explicitly approve a merged-story plan.

## Protect the live runtime

1. Run implementation and tests inside the issue worktree.
2. Use a dummy tree, temporary directory, or isolated fixture for bootstrap and shell tests.
3. Set fixture `HOME`, `XDG_CONFIG_HOME`, `MISE_DATA_DIR`, `MISE_CACHE_DIR`, and `MISE_STATE_DIR` when the test can touch user state.
4. Use `mktemp -d` for disposable fixtures. Register cleanup before the first fixture mutation.
5. Do not apply bootstrap changes to the live home directory during development.
6. Keep runtime repositories, caches, history, credentials, and generated files outside tracked sources.

## Gate commits and pushes

1. Have the implementation agent stop with an uncommitted worktree after validation.
2. Run an independent critique subagent against the complete diff and test evidence.
3. If the critique fails, use a separate fix subagent to address the findings.
4. Run the independent critique again after the fix.
5. Load `commit-guidelines` for diff review, security review, hooks, and commit messages.
6. Load `pr-guidelines` before every authorized push. Let that skill own push, base/head, manifest, and PR metadata synchronization.
7. Commit the issue implementation and its tests together when they form one atomic change.

## Watch reviews

1. Add every open PR to the repository's review-watch state.
2. Poll the watch with `mise run pr:review-watch -- poll` on an external schedule.
3. Inspect new review summaries, inline comments, review decisions, and failed checks.
4. Address actionable feedback in the matching worktree.
5. Run focused tests and an independent critique subagent before every review-fix commit and push.
6. Use `commit-guidelines` and `pr-guidelines` for the review-fix commit and push.
7. Remove merged or closed PRs from the watch state automatically.
8. Remove the matching worktree after a PR merges and the worktree is clean.
9. Close the orchestration cycle only when no open watched PR remains and no actionable review work remains.

## Merge authority

1. Never merge a pull request yourself.
2. Leave merge decisions and final review approval to me.
3. Keep an open PR in the watch state until GitHub reports it merged or closed.
4. Report blocked merge state, required reviews, failed checks, and unresolved comments plainly.

## State tracking

Use the session todo store for lane state, dependencies, critique cycles, and PR handoff status. Use the `pr:review-watch` state file only for open PR review polling. Keep temporary reports in the session workspace or an ignored project `tmp/` directory.
