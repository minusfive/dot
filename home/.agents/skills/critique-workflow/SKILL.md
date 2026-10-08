---
name: critique-workflow
description: Run critique, review, and audit workflows for agent instructions and prose, with verdicts and writing-style enforcement. Use when I ask for a critique, review, or audit.
---

# Critique Workflow

Use this skill for critique, review, and audit tasks.

## Mode Selection

Choose exactly one mode and follow that mode file end-to-end:

- Use [`assets/human-walkthrough.md`](assets/human-walkthrough.md) when I explicitly ask for interactive walkthrough critique with decision gates.
- Use [`assets/autonomous-cycle.md`](assets/autonomous-cycle.md) for deterministic unattended critique/review/audit cycles.
- Default to autonomous mode unless I explicitly ask for interactive walkthrough mode.

Do not mix steps across modes. The selected mode file is the full executable procedure.

## `writing-style` Evaluation

- When the critique scope includes authored prose or instruction text, load `writing-style`, then `simple-english`, before final verdicts.
- Evaluate prose and instruction wording against `writing-style` guidance and record style findings with the standard status tokens.
- When style review is out of scope, record one explicit `NOTE` that `writing-style` evaluation is not applicable.
