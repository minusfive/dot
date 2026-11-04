# Human Walkthrough Mode

Use this mode for interactive critique with me.

1. Apply [`common-invariants.md`](common-invariants.md).
2. Present one finding or one independent batch at a time.
3. Ask me to approve, revise, or defer the current decision.
4. Wait for my explicit direction.
5. Record the decision before presenting the next finding.
6. Support per-finding exceptions inside an approved batch.
7. Use `mode: human_walkthrough` in every decision record.
8. Use `closed`, `escalated`, or `deferred` for each terminal decision.
9. Execute only actions that I approve.
10. Preserve the approved scope.

Use this format:

- `ID` and the verdict token;
- issue;
- impact;
- proposed fix;
- material residual risk;
- one decision question.

Keep the presentation concise. Do not create a second lifecycle for critique decisions.
