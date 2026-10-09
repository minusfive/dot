---
name: agent-instructions-evaluation
description: Evaluate agent-instruction behavior and discoverability with repeatable baselines, assertion grading, benchmark deltas, and iteration loops. Use when revising skills, AGENTS.md, CLAUDE.md, or agent-definition instructions.
---

Canonical reference: [Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills)

# Agent Instructions Evaluation

Use this skill when validating quality for new or updated agent-instruction
entrypoints, or when tuning whether instruction changes activate for the right
user requests.

## When to Run

- Run for non-trivial behavior edits in instruction entrypoints (for example,
  `SKILL.md`, `AGENTS.md`, `CLAUDE.md`, and agent/subagent definitions).
- Run for selector/discoverability edits that may change trigger behavior
  (for example, frontmatter `description`, skill-index summaries, or routing
  wording).
- Run for renames, splits, or merges of instruction files/skills.
- Skip only for tiny edits that cannot affect behavior (for example, typo-only
  fixes with no semantic change).

## Instruction Behavior Eval Loop

1. Create or update the tracked eval spec at `evals/evals.json` with the
   canonical `skill_name` and `evals` top-level keys. Give every case a stable,
   descriptive kebab-case `id` that names the behavior under test. Reuse the
   exact case IDs in workspace paths, manifests, and report keys. Each case
   should include `prompt`, `expected_output`, and optional input `files`.
   Start with 2-3 cases, then expand.
2. Use a separate workspace for iteration results. Keep generated run artifacts
   out of the skill directory.
3. Run each case in isolated context twice:
   - with updated instructions
   - with a baseline (without the changed instructions, or a snapshot of the
     previous version when iterating on an existing entrypoint)
4. Store outputs per case and config under
   `<workspace>/iteration-N/<eval-id>/{with_skill,without_skill}/outputs/`
   (or `old_skill/` instead of `without_skill/` for version-to-version
   comparisons).
5. Capture `timing.json` for each run under its
   `<workspace>/iteration-N/<eval-id>/<configuration>/` directory with
   `total_tokens` and `duration_ms`.
6. Add `assertions` to each eval case after first outputs are available.
   Assertions must be specific and verifiable.
7. Grade each assertion as pass/fail with concrete evidence in the matching
   run directory's `grading.json`. Prefer scripted checks for mechanical
   assertions (file existence, valid JSON, row counts, dimensions, and more).
8. Aggregate run metrics into
   `<workspace>/iteration-N/benchmark.json` with per-config pass rate, time,
   token use, and delta.
9. Apply a human review pass over outputs and save actionable notes in
   `<workspace>/iteration-N/feedback.json` to catch quality issues outside
   strict assertions.
10. Iterate instructions based on failed assertions, human feedback, and
    execution transcripts. Focus on generalizable fixes, not one-off patches.

## Discoverability and Trigger Eval Loop

1. Build an eval query set (`~20` queries) with:
   - should-trigger prompts
   - should-not-trigger near-misses
   - routing-regression prompts for overlapping-scope instruction skills (for example, `perform a critique of these agent instructions` and `audit this AGENTS.md skill routing`) with explicit expected-skill assertions
2. Keep prompts realistic (varied phrasing, explicit and implicit intent,
   different detail levels, casual language/typos where plausible).
3. Split queries into fixed train/validation sets (about 60/40), with both
   classes represented in each split.
4. Run each query multiple times (3+ runs) and compute trigger rate.
5. Evaluate pass/fail by label and threshold (0.5 default unless project
   standards set a different threshold).
6. Revise selector wording (for example, skill `description` or index summary)
   using train-set failures only; select the best iteration by validation pass
   rate.
7. Avoid overfitting to specific failed-query keywords; generalize by intent.
8. Keep final frontmatter descriptions within the spec limit.

## Analysis and Acceptance Criteria

- Remove or replace assertions that always pass in both configurations.
- Investigate assertions that always fail in both configurations before taking
  quality conclusions.
- Treat high variance across repeated runs as ambiguity or flakiness; tighten
  instructions or test design accordingly.
- Treat large time/token regressions as explicit trade-offs that must be
  justified by meaningful quality gains.
- Do not ship instruction behavior changes without evidence-backed improvement
  relative to baseline (or an explicit, justified trade-off).

## References

- [Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills)
- [Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
