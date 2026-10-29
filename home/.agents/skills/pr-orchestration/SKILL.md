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
6. Apply `task-orchestration`'s dependency classifications, ready queue, checkpoint ledger, and explicit handoff rules.
7. Apply the `serialized shared-mutation lane` rules to any issue lane that shares a worktree or ref. Direct-main instruction updates are one example; keep independent feature and fixture lanes isolated.
8. Integrate each unit when its lane's dependency boundary is ready. Serialize only shared-file changes, rebases, integrations, and merges.
9. Rebase a lane onto a new `main` commit before delivery when the ledger marks that commit as a dependency.
10. Keep independent lanes running. Do not wait for optional synchronization, an unrelated critique, or another issue lane's completion. Wait for a shared-worktree or shared-ref update only when its ledger entry is the applicable hard or rebase/delivery dependency for that lane.
11. Do not use one PR for multiple issue plans unless I explicitly approve a merged-story plan.

## Gate commits and pushes

This gate reviews the integrated PR diff before delivery. `execution-workflow` owns the story `critique -> done` transition.

1. Have each implementation unit return a validated, uncommitted worktree.
2. Run an independent critique subagent against the complete diff and test evidence.
3. If the critique fails, use a separate fix subagent to address the findings.
4. Run the independent critique again after the fix.
5. Follow `commit-guidelines` for commit review, grouping, hooks, and messages.
6. Follow `pr-guidelines` before every authorized push and PR metadata update.
7. Follow `AGENTS.md` for separate current-turn commit and push authorization.
8. Apply this gate only to the matching PR. Unrelated critique results do not block delivery.
9. After authorization and critique, assign a delivery agent to perform the authorized commit, push, and PR actions.
10. Verify the resulting commit and PR metadata in the `orchestrator`.

## Watch reviews

1. Add every open PR to the repository's review-watch state.
2. Treat `mise run pr:review-watch -- poll` as a one-shot poll, not a background watcher or notification channel.
3. Invoke the poll manually or through an external schedule, and consume its machine-readable JSON.
4. The task does not notify a background agent; the scheduler or poll invocation returns findings to the orchestrator.
5. Treat a nonzero poll exit as a failed poll with no state advance.
6. Fetch and parse every complete new review body and all review comments, including comments without `path` or `line`, review summaries, and outside-diff sections, regardless of `review_decision` or empty inline-comment pages.
7. On every review cycle, enumerate unresolved findings from review bodies, review summaries, inline threads, issue comments, and outside-diff sections. Validate each finding. Treat outside-diff review-body findings, unverified findings, minor findings, and comments without threads as actionable while they are unresolved.
8. Keep a complete finding ledger with its source, validation evidence, disposition, and state.
9. Use this finding ledger matrix:
   - `unresolved` + provisional `fix`: the fix is in progress or awaiting post-push confirmation. This state blocks progress.
   - terminal `resolved`: the fix is pushed, validated, replied to, resolved in its thread when one exists, and confirmed by post-push review.
   - terminal `rejected`: record evidence-backed rejection in the ledger and applicable review channel.
   - terminal `accepted-risk`: record evidence-backed residual risk in the ledger and applicable review channel.
10. Require evidence for every terminal disposition. Only unresolved findings block progress. Reconcile the ledger after every poll and every review-fix push.
11. Keep each PR under review watch. Use only the lanes and backward-transition rules defined by `execution-workflow` for review work, normally `Research` or `Critique`. Leave that lane only when no finding is unresolved and every finding has a terminal disposition. An `APPROVED` review does not satisfy this gate.
12. For findings with a `fix` disposition, address each finding in the matching worktree. Run an independent critique, fix, focused tests, and authorized push before the next review poll.
13. For each `fix` disposition, reply in the corresponding review thread after the push and resolve it when the fix fully addresses it. If no thread exists, record the reply and disposition through the applicable review channel and in the ledger.
14. For an evidence-backed `rejected` or `accepted-risk` disposition, record the evidence and disposition in the ledger and applicable review channel. Do not create a fix push for these dispositions.
15. After every poll and review-fix push, reconcile PR state, issue state, project-card lane, dependencies, blockers, finding ledger, and watch state. Do this before continuing. Follow `execution-workflow` for every backward review transition and to reconcile issue and project-card lanes after each review cycle. Reopen a closed issue and move its card back when review work moves the story backward.
16. Continue review polling, triage, and independent fixes while unrelated work runs.
17. After a poll shows no actionable findings, reconcile the ledger before starting or continuing the grace period. Start or continue the grace period only when the review state is `APPROVED`, the unresolved finding ledger is empty, and all required checks are clean and non-pending. Keep the PR watched for four additional checks at 15-minute intervals because later automated reviews can appear.
18. Approval alone cannot move a story to `Done` or close its issue. Approval alone cannot remove its PR from watch or end or shorten the review grace period.
19. Remove an open PR only after the grace period is clean and the unresolved finding ledger is empty. Do this only when all required checks are clean and non-pending. Remove merged or closed PRs from the watch state automatically.
20. Limit review-fix cycles to 10 per PR.
21. If actionable findings remain after the tenth cycle, stop the cycle and report the remaining findings.
22. Use `commit-guidelines` and `pr-guidelines` for every review-fix commit and push.
23. Remove the matching worktree after a PR merges and the worktree is clean.
24. Stop the external schedule when all watched PRs satisfy the grace period, and close the orchestration cycle when no actionable review work remains.

## Merge authority

1. Never merge a pull request yourself.
2. Leave merge decisions and final review approval to me.
3. Keep an open PR in the watch state until GitHub reports it merged or closed, except remove it after the documented four-clean-check grace period is clean.
4. Report blocked merge state, required reviews, failed checks, and unresolved comments plainly.

## State tracking

Use the session todo store for PR lane state, dependencies, and handoff. Follow `execution-workflow` for story status and critique-cycle records in those same todos. Use the `pr:review-watch` state file only for open PR polling. Keep temporary reports in the session workspace or an ignored project `tmp/` directory.
