# Autonomous Mode

Use this mode for deterministic unattended critique cycles.

1. Apply [`common-invariants.md`](common-invariants.md).
2. Do not wait for approval.
3. Record each decision before applying its approved action.
4. Use `mode: autonomous` in every decision record.
5. Use at most three complete cycles.
6. Treat confidence as a routing signal only.
7. Keep high-impact `FAIL` findings open when confidence is low.
8. Keep unresolved `FAIL` findings open when the cycle limit is reached.
9. Execute only actions recorded as approved in the decision log.
10. End with `closed`, `escalated`, or `deferred`.

A cycle reviews findings, updates decisions, critiques the decision log, and updates dispositions. Do not add a workflow lifecycle to this critique cycle.
