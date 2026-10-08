# Human Walkthrough Mode

Use this mode for interactive critique with explicit decision gates.

## Procedure

1. Apply all shared invariants in [`common-invariants.md`](common-invariants.md).
2. Present one batch or standalone finding at a time.
3. Ask me how to proceed on the current item.
4. Wait for explicit direction.
5. Do not move to the next item until the current decision is recorded.
6. Support per-finding exceptions inside each approved batch.
7. Execute only user-approved actions and preserve the decided scope.
8. Set `mode` to `human_walkthrough` in each decision record.
9. Use `terminal_state` values with semantics defined in [`common-invariants.md`](common-invariants.md).
10. In human interaction mode, you may use harness-supported color or formatting for readability, but keep canonical status tokens in text.
11. Do not require `decision_rationale` or `closure_criteria` by default; include them only when I explicitly ask or when policy requires them.

## Presentation Format

Use a compact, scan-friendly format for each item:

- `ID` + `status_token` on the first line.
- One short line each for issue, impact, and proposed fix.
- End with a single clear decision prompt (for example: `Approve`, `Revise`, or `Defer`).
- Keep prose concise; avoid long narrative unless I ask for detail.

## Shared Requirements

- Follow the shared procedure, decision-log schema, and terminal-state definitions in [`common-invariants.md`](common-invariants.md).
