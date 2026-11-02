# Common Critique Invariants

Apply these invariants in both critique modes.

## Findings procedure

1. Build a complete findings set.
2. Assign each finding a stable identifier.
3. Cluster findings that one correction can resolve.
4. If the set is empty, record an explicit no-findings result with residual risks or confidence limits.
5. Present grouped and ungrouped findings in deterministic numeric order.
6. Include the issue, impact, suggested fix, and material residual risk for each finding.
7. Use `PASS`, `FAIL`, `RISK`, or `NOTE` for each finding and decision.

When the scope includes authored prose or instruction text, load `writing-style` and `simple-english`. Evaluate the prose before the decision-log critique. Record one `NOTE` when style review is not applicable.

After all findings have decisions, critique the decision log. Check for decision conflicts, unresolved risks, and unverified assumptions. Resolve those issues before execution. If a decision changes downstream findings, restate the updated assumptions before continuing. Keep each finding self-contained.

## Required decision-log fields

- `batch_id`;
- `finding_id`;
- `status_token`;
- `issue`;
- `evidence_refs`;
- `impact`;
- `confidence`;
- `decision`;
- `residual_risks`;
- `mode`;
- `terminal_state`.

Use `human_walkthrough` or `autonomous` for `mode`. Use `closed`, `escalated`, or `deferred` for `terminal_state`.

Optional fields are `closure_criteria` for explicit follow-up gates and `decision_rationale` for non-obvious or policy-sensitive decisions.

Use these terminal-state meanings:

- `closed`: no unresolved blocking `FAIL` remains;
- `escalated`: a blocking risk or control limit prevents safe closure;
- `deferred`: the scope is postponed with explicit reasons and dependencies.

## Boundary

The decision log records critique decisions. It does not replace a story lifecycle, review ledger, security finding ledger, or delivery state. Use the owning skill for those states.
