# Autonomous Mode

Use this mode for deterministic unattended critique cycles.

## Procedure

1. Apply all shared invariants in [`common-invariants.md`](common-invariants.md).
2. Do not wait for approvals.
3. Apply policy gates, record decision state, and continue until a terminal state is reached.
4. Enforce a hard cap at `max_loops = 3` with no override.
5. Treat confidence as a routing signal only; do not close high-impact `FAIL` items based on confidence alone.
6. If unresolved `FAIL` findings remain at loop cap, stop and escalate with a useful final output for further investigation.
7. Execute only policy-approved actions recorded in the decision state and preserve the decided scope.
8. Set `mode` to `autonomous` in each decision record.

## Loop Definition

A `loop` is one full autonomous cycle of:

- findings review
- decision updates
- decision-log critique
- disposition update (`closed` | `escalated` | `deferred`)

## Shared Requirements

- Follow the shared procedure, decision-log schema, and terminal-state definitions in [`common-invariants.md`](common-invariants.md).
