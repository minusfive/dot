---
name: pr-orchestration
description: Orchestrate multi-issue GitHub delivery with durable issue plans, independent worktrees, separate PRs, isolated dummy-tree tests, critique gates, review watching, and manual merge handoff. Use when a request spans multiple issues or asks for parallel PR execution.
---

# Pull Request Orchestration

Use this skill for multi-issue work that needs separate branches, worktrees, pull requests, review cycles, or manual merge handoff.

Use the `orchestrator` agent as the primary coordinator. Follow `task-orchestration` for assignment sizing, isolation, supervision, and recovery.

## Start with durable plans

1. Load `planning` before drafting or refining a plan.
2. Defer plan research, decision resolution, story fields, research matrices, and planning critique to `planning`.
3. Treat each issue description as the canonical plan when I identify issues as the plan source.
4. Refine each issue description before implementation.
5. Use `planning` for plan content. Follow `task-orchestration` for planning delegation and recovery.
6. Use an independent critique subagent for every proposed plan update before submitting it to GitHub.
7. Record plan updates and critique outcomes in the issue. Keep the issue description as the maintained plan.

## Build independent lanes

1. Build a dependency graph from the issue plans.
2. Create one integration branch and worktree per issue.
3. Keep issue lanes independent. Do not share mutable source files between lanes.
4. Delegate balanced behavior units through `task-orchestration`.
5. Follow its runtime-isolation rules for parallel worktrees and dependent branches.
6. Integrate completed units into their issue lane. Serialize shared-file changes and merges.
7. Do not use one PR for multiple issue plans unless I explicitly approve a merged-story plan.

## Gate commits and pushes

This gate reviews the integrated PR diff before delivery. `execution-workflow` owns the story `critique -> done` transition.

1. Have each implementation unit return a validated, uncommitted worktree.
2. Run an independent critique subagent against the complete diff and test evidence.
3. If the critique fails, use a separate fix subagent to address the findings.
4. Run the independent critique again after the fix.
5. Follow `commit-guidelines` for commit review, grouping, hooks, and messages.
6. Follow `pr-guidelines` before every authorized push and PR metadata update.
7. Follow `AGENTS.md` for separate current-turn commit and push authorization.
8. After authorization and critique, assign a delivery agent to perform the authorized commit, push, and PR actions.
9. Verify the resulting commit and PR metadata in the `orchestrator`.

## Watch reviews

1. Add every open PR to the repository's review-watch state.
2. Treat `mise run pr:review-watch -- poll` as a one-shot poll, not a background watcher or notification channel.
3. Invoke the poll manually or through an external schedule, and consume its machine-readable JSON.
4. The task does not notify a background agent; the scheduler or poll invocation returns findings to the orchestrator.
5. Treat a nonzero poll exit as a failed poll with no state advance.
6. Fetch and parse every complete new review body and all review comments, including comments without `path` or `line`, review summaries, and outside-diff sections, regardless of `review_decision` or empty inline-comment pages.
7. On every review cycle, enumerate and validate all unresolved findings from review bodies, review summaries, inline threads, issue comments, and outside-diff sections.
8. Keep a finding ledger with its source, validation evidence, and disposition: fix, reject with evidence, or accepted residual risk. Complete the ledger before moving the PR or story forward.
9. Address every actionable finding in the matching worktree. For each one, run an independent critique, fix, focused tests, and authorized push before the next review poll.
10. Reply in the corresponding review thread after each fix and resolve it when the fix fully addresses it. If no thread exists, record the reply and disposition through the applicable review channel and in the ledger.
11. Follow `execution-workflow` to reconcile issue and project-card lanes after each review cycle. Reopen a closed issue and move its card back when review work moves the story backward.
12. After a zero-finding review, keep the PR watched for four additional checks at 15-minute intervals because later automated reviews can appear.
13. Remove an open PR only after that grace period is clean. Remove merged or closed PRs from the watch state automatically.
14. Limit review-fix cycles to 10 per PR.
15. If actionable findings remain after the tenth cycle, stop the cycle and report the remaining findings.
16. Use `commit-guidelines` and `pr-guidelines` for every review-fix commit and push.
17. Remove the matching worktree after a PR merges and the worktree is clean.
18. Stop the external schedule when all watched PRs satisfy the grace period, and close the orchestration cycle when no actionable review work remains.

## Merge authority

1. Never merge a pull request yourself.
2. Leave merge decisions and final review approval to me.
3. Keep an open PR in the watch state until GitHub reports it merged or closed, except remove it after the documented four-clean-check grace period is clean.
4. Report blocked merge state, required reviews, failed checks, and unresolved comments plainly.

## State tracking

Use the session todo store for PR lane state, dependencies, and handoff. Follow `execution-workflow` for story status and critique-cycle records in those same todos. Use the `pr:review-watch` state file only for open PR polling. Keep temporary reports in the session workspace or an ignored project `tmp/` directory.
