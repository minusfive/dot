---
name: planning-determinism
description: Planning-phase completeness gates. Use when transitioning from planning to execution on multi-step, high-risk, ambiguous, or multi-file tasks.
user-invocable: false
---

# Planning Determinism

Use this skill to enforce a deterministic transition from planning to execution.

## Scope

Apply this skill when work is multi-step, high-risk, ambiguous, or touches multiple files.

## Required Planning Gates

Before execution, confirm all of the following:

1. **Exploration complete**: relevant codepaths, docs, and constraints are identified.
2. **Evaluation complete**: viable options were compared and tradeoffs assessed.
3. **Decision log complete**: chosen approach is explicit; rejected alternatives are noted.
4. **Unknowns handled**: unknowns are resolved or converted into explicit user questions.
5. **Deterministic sequence**: execution steps are ordered, concrete, and testable.
6. **Failure protocol ready**: rollback/mitigation approach is clear for risky operations.

## Execution Guardrails

- Do not start execution with unresolved decision branches.
- Do not leave implementation-critical steps as `TBD` or "decide later."
- If new unknowns appear during execution, stop and re-enter planning for that scope.

## Output Shape

When producing or validating a plan, include:

1. Discovery summary
2. Option/tradeoff analysis
3. Decision log
4. Assumptions and risks
5. Deterministic execution checklist
6. Open questions (if any)
