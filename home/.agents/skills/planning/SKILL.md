---
name: planning
description: Create execution-ready plans with resolved decisions, research matrices, story artifacts, amendments, and exact handoffs. Use when work is multi-step, high-risk, ambiguous, or spans multiple files or services.
---

# Planning

Use this skill to create and maintain the accepted plan artifact before execution.

Use `workflow-policy` for assignment boundaries, isolation, checkpoints, and recovery. Use `execution-workflow` for story execution after the plan is accepted.

## Plan artifact

Create one plan artifact for the current objective.

Include these sections:

1. Objective.
2. Resolved decisions and assumptions.
3. Research matrix.
4. Topologically ordered story blocks.
5. Acceptance and verification checks.
6. Rollback or mitigation.
7. Exact execution handoff.

Make every story a vertical slice. Include the affected layers, focused tests, end-to-end checks, and behavior-coupled documentation in its story. Give every story a stable machine-parseable key, dependencies, numbered steps, acceptance checks, and rollback notes. Keep story dependencies topologically valid. Do not defer implementation-critical research or decisions to execution.

## Decision resolution

Explore the repository, documentation, tests, and live tool surfaces before asking me a question. State the recommended answer before each question. Ask one question at a time. Batch questions only when they are independent, and limit a batch to three questions. Resolve upstream decisions before downstream decisions. Record each decision, evidence reference, owner, and effect on scope in the plan artifact. Stop planning when I am unavailable for a required decision. Preserve the evidence and do not present an accepted plan with unresolved implementation-critical decisions.

## Research matrix

Size the matrix to the current objective. Do not create a repository-wide inventory when the scope is fixed.

Record one row for each affected behavior or boundary. Include:

- source and target paths, relative to `~`;
- ownership mode and runtime exclusions;
- code or configuration coupling;
- focused and end-to-end validation;
- rollback or mitigation;
- final disposition and handoff owner.

Record unknowns as questions. Resolve every unknown that can change execution order, scope, ownership, or acceptance before the handoff.

## Freeze and amendment

Freeze the plan when I accept the plan artifact. Execution consumes the accepted artifact without rewriting story specifications. Treat missing, inconsistent, or non-actionable plan fields as execution drift. Use `execution-workflow` to block the affected story and preserve its evidence. Create a targeted amendment when evidence shows that the accepted plan cannot satisfy its objective or acceptance checks, or when any material boundary changes.

Planning owns the recovery decision and the decision to amend a plan. After `workflow-policy` completes the canonical `freeze -> report -> escalate -> stop` sequence and `execution-workflow` blocks the affected story, review the preserved report, evidence, and critique. If the accepted plan remains viable and acceptance, scope, ownership, dependencies, security, feasibility, and delivery boundaries remain unchanged, record a plan-preserving recovery decision. Do not create an amendment or a new plan version. Execution can resume the blocked story at `research` after that decision. A missing, inconsistent, or non-actionable required story field makes the plan non-viable, even when those boundaries remain unchanged. Create and accept a targeted amendment with a new plan version before execution resumes. If any one of those boundaries changes, create and accept a targeted amendment with a new plan version before execution resumes.

Planning owns amendment critique and acceptance. Use `critique-workflow` to critique every amendment, record the decision, and accept or reject the patch only after that critique and before execution consumes it. `review-delivery` reviews only candidates and pull requests.

Each amendment must record:

- the exact plan artifact path;
- the affected story keys;
- the evidence that requires the change;
- the changed fields;
- the new dependencies or acceptance effects;
- the rollback or mitigation;
- the critique evidence;
- the acceptance decision and version;
- the required execution handoff.

Do not create a second lifecycle. Keep the original plan history and make the amended artifact the new accepted source only after the planning critique and acceptance decision.

## Execution handoff

Persist the accepted plan at the canonical location and name defined by `agentic-projects`. Include the exact persisted path in the handoff. Require `execution-workflow` to consume that exact path. Do not infer a default plan path.

Include:

- the exact plan artifact path;
- the accepted plan version or amendment identifier;
- the current-turn authorization scope and expiry;
- story order and dependency gates;
- concurrency boundaries;
- vertical integration checkpoints;
- runtime exclusions;
- focused validation commands;
- rollback or mitigation;
- user-unavailable behavior.

After acceptance, load `execution-workflow`. Keep plan content in this skill and story lifecycle in `execution-workflow`.
