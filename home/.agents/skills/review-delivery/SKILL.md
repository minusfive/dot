---
name: review-delivery
description: Review a fixed candidate, disposition findings, and hand off pull request delivery without merging. Use when work needs candidate identity, review cycles, rebases, pull requests, or manual merge handoff.
---

# Review and Delivery

Use this skill for candidate review, pull request delivery, and manual merge handoff.

Use `workflow-policy` for assignment boundaries, isolation, checkpoints, and recovery. Use `execution-workflow` for story state and critique-cycle transitions. Use `commit-guidelines` and `pr-guidelines` for authorized delivery steps.

This skill owns candidate identity, fixed-candidate review, finding disposition, pull request and rebase handoffs, and merge authority boundaries. Do not create a second lifecycle. Use `execution-workflow` for story transitions.

## Candidate identity

Treat the accepted plan and its exact artifact path as the candidate's source. Assign each candidate a stable `candidate_id`, `lane_id`, `artifact_id`, worktree path, and ref. Record owned paths, excluded paths, acceptance checks, dependencies, and authorization scope. Keep these fields fixed during review.

If a candidate path, ref, worktree, owned path, acceptance check, or artifact changes, stop the review. Record candidate drift and route the story through `execution-workflow` and `planning`. Do not silently review a different candidate.

Use the accepted Project/issue graph to define logical candidate boundaries. Apply these rules:

- One graph can produce one or more grouped or split pull request candidates.
- One issue can span candidates.
- One candidate can span issues.
- Use subissues to track decomposition and dependencies.

Assign each candidate its own worktree and pull request unless I explicitly approve another delivery boundary. Keep unrelated candidates isolated. Serialize only a shared-file mutation, rebase, integration, or delivery boundary recorded as a dependency.

## Fixed-candidate review

Review the complete candidate diff and validation evidence. Run an independent critique before an authorized commit, push, or pull request update. Keep the candidate fixed between review and delivery. If critique fails, record the finding, apply the approved fix in the matching worktree, validate it, and run critique again.

Review each pull request with a one-shot review poll. Parse review bodies, review summaries, inline threads, issue comments, and outside-diff findings. Treat every unresolved finding as actionable, including comments without a path or thread. Keep the candidate in review until every finding has a terminal disposition. An approval does not close an unresolved finding. Treat a nonzero poll result as a failed poll with no state advance.

Treat a review summary as a container for findings, not as the complete finding set. If it reports an `Additional comments: N` count, enumerate all `N` nested findings. Reconcile those findings with inline comments, replies, outside-diff findings, and thread resolution state before making a disposition.

Count the raw nested comment artifacts before you classify findings. Treat each reply as evidence for its parent unless it adds a distinct finding. If the reported count differs from the collected artifact count, block disposition. Record an incomplete review poll.

Delegate the complete review poll and candidate validation to a review-monitoring worker. The worker must inventory every review artifact, reconcile each finding, and run bounded validation. Consume its evidence instead of repeating the same review scope in the orchestrator.

## Review-watch handoffs

Set up watch state with `mise run pr:review-watch -- add <pull-request-number>`. Record the state-file path and the candidate identity in the delivery evidence.

Run `mise run pr:review-watch -- poll` as a one-shot poll from an external scheduler. The scheduler owns cadence, retry limits, and shutdown. The task owns one atomic poll and state update.

Treat a nonzero poll result, malformed response, or unavailable review service as a failed poll. Preserve the prior watch state, record the error, and do not advance review or delivery state.

Inspect new reviews, inline comments, issue comments, failed checks, and pending checks from each successful poll. Fix actionable findings in the matching candidate worktree, run independent critique and validation, then use the authorized delivery handoff.

Remove a merged or closed pull request with `mise run pr:review-watch -- remove <pull-request-number>`. Stop the external schedule only when the poll output sets `scheduler_should_stop: true`: every watched open pull request completed its four-check clean grace period, or closed/merged and was removed. An empty actionable queue is not sufficient.

Record delivery evidence for each candidate: the review poll output, finding ledger, validation results, authorized ref update, pushed ref, review response, and later poll confirmation. Keep the candidate fixed across these records.

Report `delivery complete` only after recording linked pull request, completed review, and manual-merge handoff evidence. This status does not close an issue. Use `execution-workflow` for `story/issue done` and current-turn root authorization.

## Finding disposition

Maintain a finding ledger with the source, candidate identity, validation evidence, disposition, and state.

Use these states:

- `unresolved` with provisional `fix`;
- terminal `resolved`;
- terminal `rejected`;
- terminal `accepted-risk`.

Only `resolved` findings can close after the fix is pushed, validated, answered in the review channel, resolved in its thread when one exists, and confirmed by a later review. Record evidence for `rejected` and `accepted-risk`. Do not push a fix for those terminal dispositions. Reconcile the ledger after every poll and review-fix push.

Limit review-fix cycles to ten per pull request. Stop and report remaining findings after the tenth cycle.

## Rebase and delivery handoffs

Rebase a candidate only when the dependency ledger records a rebase or delivery dependency. Serialize the rebase and delivery operation. Validate the candidate again after the rebase. Record the handoff, new ref, validation evidence, and candidate identity.

After independent critique and validation, assign only explicitly authorized commit, push, and pull request metadata mutations to a delivery worker. The delivery worker performs the authorized mutations and returns evidence. The orchestrator owns scope, authorization, integration decisions, and post-delivery verification. Preserve current-turn authorization and stop the lane when authorization expires.

Keep an open pull request under review watch until GitHub reports it merged or closed, except for the documented clean grace period. Remove merged or closed pull requests from watch state under the approved watch policy. Start the clean grace period only when the review is approved, the unresolved finding ledger is empty, and required checks are clean and non-pending. Keep the pull request watched for four additional checks at 15-minute intervals. Do not stop the scheduler while any watched open pull request has not completed that grace period. Do not remove an open pull request before the clean grace period ends. Approval alone cannot move a story to `Done`, close its issue, remove its pull request from watch, or end the grace period.

## Merge authority

Never merge a pull request. Leave merge decisions and final approval to me. Report blocked merge state, required reviews, failed checks, and unresolved findings plainly.

If I am unavailable for a required decision, preserve the finding ledger and freeze delivery. Do not change candidate identity, disposition, authorization, or merge state while the decision is pending.
