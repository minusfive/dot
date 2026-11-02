---
name: critique-workflow
description: Run deterministic critique, review, and audit modes for agent instructions and prose. Use when I ask for a critique, review, or audit.
---

# Critique Workflow

Use this skill for critique, review, and audit work.

Choose exactly one mode:

- [`assets/human-walkthrough.md`](assets/human-walkthrough.md) for interactive decisions with me.
- [`assets/autonomous-cycle.md`](assets/autonomous-cycle.md) for unattended decisions.

Default to autonomous mode unless I ask for an interactive walkthrough. Follow the selected mode and [`assets/common-invariants.md`](assets/common-invariants.md) end to end. Do not mix modes.

## Findings

Build a complete findings set before execution. Assign each finding a stable identifier. Cluster findings that one correction can resolve. Search the full applicable repository scope for matching occurrences. Apply the same correction to every match unless evidence supports an exclusion.

Use the canonical ASCII verdict tokens:

- `PASS`;
- `FAIL`;
- `RISK`;
- `NOTE`.

Present findings as a numbered list. Include the issue, impact, suggested fix, and material residual risk.

## Decision records

Record each finding and decision in a compact machine-readable decision log. Use the required fields in `assets/common-invariants.md`. Set `mode` to the selected mode. Use `closed`, `escalated`, or `deferred` for the decision-log terminal state.

When the scope includes authored prose or instruction text, evaluate it with `writing-style` and `simple-english` before final decisions. Record one explicit `NOTE` when style review is not applicable.

After all findings have decisions, critique the decision log. Check for conflicting decisions, unresolved risks, and unverified assumptions. Resolve decision-log issues before execution.

Keep decision-log terminal states separate from the repository workflow lifecycle. Use the owning skill for implementation, story, review, security, and delivery state.
