---
name: planning
description: Produce execution-ready implementation plans for complex work. Use when tasks are multi-step, high-risk, ambiguous, or span multiple files/services.
---

# Planning

Use this skill as the canonical source for planning behavior and transition-to-execution readiness.

## Required Planning Gates

Before execution, confirm all of the following:

1. **Exploration complete**: relevant codepaths, docs, and constraints are identified.
2. **Unknowns handled**: unknowns are resolved or converted into explicit user questions.
3. **Conversational planning complete**: planning interaction challenges assumptions, pressure-tests risks, and avoids passive transcription.
4. **Critique pass complete**: every time the plan is updated, apply the canonical critique gate defined in `AGENTS.md` before presenting the updated plan to the user.
5. **Deterministic sequence**: execution steps are ordered, concrete, and testable.
6. **Failure protocol ready**: rollback/mitigation approach is clear for risky operations.

## Conversational Peer Behavior

- Act like a highly experienced peer reviewer, not a recorder.
- Challenge assumptions directly and propose concrete corrections when assumptions are weak.
- Surface blind spots, edge cases, and sequencing risks.
- Ask focused clarifying questions when requirements are ambiguous.
- Keep the planning loop interactive until execution steps are unambiguous.

## Execution Guardrails

- Do not start execution with unresolved decision branches.
- Do not leave implementation-critical steps as `TBD` or "decide later."
- If new unknowns appear during execution, stop and re-enter planning for that scope.

## Plan Output Requirements

When producing or validating a plan, include only actionable execution instructions:

1. Objective
2. Ordered execution steps
3. Explicit dependencies and sequencing constraints
4. Verification/acceptance checks

All open questions must be resolved during the planning conversation before presenting final plan output.
Do not include decision-making history, tradeoff history, or rationale narrative in final plan output.
