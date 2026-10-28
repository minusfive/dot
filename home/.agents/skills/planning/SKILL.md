---
name: planning
description: Produce deterministic execution plans with story artifacts ready for workflow-driven delivery. Use when tasks are multi-step, high-risk, ambiguous, or span multiple files/services.
---

# Planning

Use this skill to produce execution-ready plans before implementation.

Use the `orchestrator` agent as the primary coordinator. Follow `task-orchestration` for delegated planning assignments and supervision.

If you are a planning worker, return your plan draft, research matrix, evidence, and unresolved questions to the `orchestrator`. Do not ask me directly. The `orchestrator` asks me remaining questions and accepts the plan.

## Planning Loop

1. Explore relevant codepaths, docs, and constraints first.
2. Enumerate ambiguous branches and unknowns explicitly.
3. Interview the plan across the full design tree:
   - Challenge assumptions directly, surface blind spots/edge cases/sequencing risks, and avoid passive transcription.
   - Ask one question at a time and wait for feedback before continuing; only batch questions when they are fully independent, and limit each batch to at most three questions.
   - Resolve decision dependencies one-by-one; do not advance while upstream decisions remain open.
   - If a question can be answered by exploring the codebase, investigate first and only ask when uncertainty remains.
   - For each question you ask me, provide a recommended answer first.
   - Base recommendations on concrete codebase/docs evidence when available; when evidence is unavailable, state the assumption explicitly before requesting confirmation or correction.
4. Continue until all implementation-critical decisions are resolved (decisions that materially change execution steps, ordering, or scope), no unresolved upstream dependencies remain, and no open questions remain for final plan output.
5. Once all open questions are resolved and before presenting final plan output, apply the canonical critique gate defined in `AGENTS.md`.
6. Before finalizing the plan, complete and persist a research matrix sized to the implementation scope. State the exact files, target paths, ownership mode, runtime exclusions, code coupling, validation commands, rollback, and final disposition. Do not create a full repository inventory when the scope is already fixed.
7. Make each story a complete vertical slice. A story must implement one coherent behavior across every affected layer, include its focused and end-to-end validation, and update behavior-coupled documentation or instructions.
8. Do not create horizontal stories that defer all tests, integration checks, or behavior-coupled documentation to a later story. Later stories must not be the first place that validates an earlier story's core design.
9. Generate test fixtures at runtime in temporary directories and remove them on exit. Check in fixture files only when the plan explicitly requires a stable, reviewed fixture and names its path and purpose.
10. Do not leave discovery tasks or implementation-critical decisions in story steps. Execution can run named validation commands and report drift. If a required fact is unknown, keep the work in planning and resolve it before handoff.

## Execution Readiness and Guardrails

- Do not start execution with unresolved decision branches.
- Do not leave implementation-critical steps as `TBD` or "decide later."
- Ensure execution steps are ordered, concrete, and testable.
- Ensure rollback/mitigation approach is clear before execution.
- Ensure every story leaves an end-to-end demonstrable increment before the next dependent story starts.

## Plan Output Requirements

When producing or validating a plan, include only actionable execution instructions:

1. Objective
2. Deterministic story plan artifact:
   - Format implementation work as story blocks that execution agents can follow without reinterpretation.
   - Each story block must include: stable story key, dependencies, numbered implementation steps, acceptance checks, and rollback/mitigation notes.
   - Keep story keys machine-parseable and execution order topologically valid.
   - Include the affected layers, the focused tests, and one end-to-end integration checkpoint in each story block.
   - Keep behavior-coupled documentation and instruction updates in the story that changes the behavior.
3. Execution handoff constraints:
   - Declare sequencing constraints and concurrency boundaries required by execution workflow.
   - Identify vertical integration checkpoints that execution must preserve as feedback anchors.
   - Include the exact persisted plan artifact path in the handoff and require execution to consume that exact path (no default-path inference).
   - When a plan names a file, write the full path relative to `~`.
4. Verification/acceptance checks

Keep each plan scoped to its current objective. Exclude unrelated alternatives, future work, and comparison-only options from the plan. Track deferred work in separate research or issue artifacts, and mention it in the plan only when an explicit dependency or handoff requires it.

All open questions must be resolved during the planning conversation before presenting final plan output. Do not include meta-commentary, decision-making history, tradeoff history, or rationale narrative in final plan output.

## Execution Handoff

Once the final plan artifact is accepted, load the `execution-workflow` skill to drive story delivery. Persist the accepted plan artifact using the canonical location and naming conventions defined by the `agentic-projects` skill before handoff, and include that exact plan path as an explicit handoff field for execution.
