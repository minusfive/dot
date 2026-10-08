# Common Critique Invariants

Apply these invariants in both human walkthrough and autonomous modes.

## Shared Procedure

1. Build a complete findings set and assign each finding a stable identifier.
2. Run a preliminary clustering pass to group findings that can be addressed by one cohesive solution.
3. If the findings set is empty, return an explicit no-findings verdict with residual risks or confidence caveats, then end the flow.
4. Present grouped and ungrouped findings in deterministic order, using numeric indexes.
5. For each batch or standalone finding, provide:
   - the concrete issue
   - why it matters (one line)
   - a suggested fix
   - residual risks (only when material)
6. Use explicit verdict status tokens for findings and decisions: `PASS`, `FAIL`, `RISK`, `NOTE`.
7. Record each finding and decision in a compact, machine-readable decision log keyed by finding identifier and batch identifier.
8. When scope includes authored prose or instruction text, load `writing-style`, then `simple-english`, run a `writing-style` evaluation, and include style findings before decision-log critique. When not applicable, add one explicit `NOTE`.
9. After all findings have decisions, run a dedicated critique pass on the decision log before any execution:
   - check for decision conflicts
   - check for unresolved or newly introduced risks
   - check for unverified assumptions
10. Present the decision-log critique and resolve issues before execution.
11. If a decision materially changes downstream findings, restate the updated assumptions before continuing.
12. Keep each finding self-contained so decisions do not depend on hidden context.

## Required Decision Log Fields

- `batch_id`
- `finding_id`
- `status_token` (`PASS` | `FAIL` | `RISK` | `NOTE`)
- `issue`
- `evidence_refs`
- `impact`
- `confidence` (routing only)
- `decision`
- `residual_risks`
- `mode` (`human_walkthrough` | `autonomous`)
- `terminal_state` (`closed` | `escalated` | `deferred`)

## Optional Decision Log Fields

- `closure_criteria` (include only when closure requires explicit follow-up gates)
- `decision_rationale` (include only when the decision is non-obvious or policy-sensitive)

## Terminal States

- `closed` — the final decision is recorded and no unresolved blocking `FAIL` remains.
- `escalated` — blocking risk or control limits prevent safe closure; hand off with concrete next-investigation output.
- `deferred` — scope intentionally postponed with explicit reasons and dependencies.
