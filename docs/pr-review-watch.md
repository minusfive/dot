# Pull request review watch

`mise run pr:review-watch poll` emits the poll fields plus one identity-bound `review-findings.v1` envelope in `review_findings`. Poll fields `new_reviews`, `new_inline_comments`, and `new_issue_comments` are the source for the envelope; add-time `reviews`, `inline_comments`, and `issue_comments` are normalized to the same finding format.

The envelope binds the repository, coordinator, scheduler, assignment, scope, candidate, pull request, and head identities. Set the optional identity flags (`--coordinator-id`, `--scheduler-id`, `--assignment-id`, `--scope-id`, and `--candidate-id`) when a caller owns those identities. In identity-bound mode, malformed, incomplete, count-mismatched, stale, or cross-identity batches fail before state is advanced.

Every staged result and finding carries its per-PR identity. Nested review comments retain reply, thread, revision, location, and `outside_diff` provenance. A comment is diff-located only when it has a non-empty path and a positive position; otherwise it is pathless and outside the diff.

Provider completeness uses the `gh-api-paginate-slurp-v1` contract: `gh api --paginate --slurp` must return every comment page, each page must be an array (or an explicit complete `items` page), and any declared count must match the flattened result. Review metadata uses the `gh-pr-view-reviews-v1` normalized contract: GraphQL/camel-case `submittedAt` and REST `submitted_at` are canonicalized to `submittedAt` at the provider boundary, and conflicting values are rejected before validation. Optional declared counts are reconciled when present.

Malformed legacy watch entries and staged transactions are quarantined with their raw JSON and a SHA-256 digest while valid watches remain usable. A poll failure is isolated to its pull request; the affected entry is not advanced and the failed poll does not persist any cursor updates.

Add and poll mutations are transactional: validation failures restore the prior state file byte-for-byte, and a poll does not remove or advance any watch until every watched pull request completes successfully. Adding an already-registered exact candidate is idempotent and can recover a valid staged acknowledgment without refetching activity.
