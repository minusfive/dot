---
name: agent-instructions-evaluation
description: Evaluate agent-instruction skills with deterministic specs, isolated baselines, assertion grading, benchmark reports, and discoverability checks. Use when revising or auditing skills, AGENTS.md, CLAUDE.md, or agent definitions.
---

# Agent Instructions Evaluation

Use this skill when you evaluate a changed agent-instruction entrypoint. This includes a skill, `AGENTS.md`, `CLAUDE.md`, or an agent definition.

## Storage

- Keep the durable specification at `<skill-root>/evals/evals.json`.
- Keep generated workspaces at `<repository-root>/.agents/eval-workspaces/<skill-name>/`.
- Keep each `<skill-root>/evals/` directory limited to `evals.json`.
- Keep generated outputs out of the skill directory.
- Keep generated outputs under `outputs/`. The repository Git ignore rules cover these files.
- Use the `ai:skills:evals:init` and `ai:skills:evals:prepare` tasks to create specifications, manifests, reports, and timing records.

The grouped tasks work in any Git repository that uses `.agents/skills/`. They write workspaces under that repository's `.agents/eval-workspaces/` directory. Read the repository's local instruction files when the skill source uses a non-standard path.

## Task-first workflow

Use the grouped mise tasks for every structural evaluation-file change:

1. Run `mise run ai:skills:evals:init --skill <skill-name>` to create a new specification.
2. Edit only the case content: prompts, expected results, input files, and assertions.
3. Run `mise run ai:skills:evals:prepare --skill <skill-name> --iteration <new-number>` to create a new workspace iteration.
4. Run `mise run ai:skills:evals:validate` before reviewing or grading results.
5. Run `mise run ai:skills:validate-conflicts` to check local and global skill names.
6. Run `mise run mise:tasks:validate-conflicts` to check local and global task names.

Do not create, move, or hand-edit manifests, reports, timing files, grading files, or workspace directories. Use the tasks to preserve the required names, keys, locations, and configuration directories.

## Evaluation specification

The `ai:skills:evals:init` task creates `evals/evals.json` with this top-level shape:

```json
{
  "skill_name": "skill-name",
  "evals": [
    {
      "id": "descriptive-kebab-case",
      "prompt": "A realistic request.",
      "expected_output": "The required result.",
      "files": [],
      "assertions": ["A specific result that a grader can identify."]
    }
  ]
}
```

Use the exact skill directory name in `skill_name`. Use a descriptive kebab-case string `id` for every case. Reuse each case ID in workspace paths, manifests, and reports. Keep `files` optional. Keep `expected_output` as a human-readable string. Add `assertions` after the first run as an array of verifiable strings.

Start with two or three behavior cases. Add cases only when a failed result shows that the existing cases do not cover the required behavior.

## Behavior evaluation

Run every case in two isolated configurations:

- `with_skill`: the changed instruction entrypoint.
- `old_skill`: the previous entrypoint, or the no-instruction baseline when no previous entrypoint exists.

Run each configuration at least twice. Do not compare only one response.

Store results with this layout:

```text
.agents/eval-workspaces/<skill-name>/
├── iteration-1/
│   ├── manifest.json
│   ├── benchmark.json
│   ├── feedback.json
│   ├── grading-summary.json
│   └── <case-id>/
│       ├── with_skill/
│       │   ├── outputs/
│       │   │   └── run-1.txt
│       │   ├── timing.json
│       │   └── grading.json
│       └── old_skill/
│           ├── outputs/
│           │   └── run-1.txt
│           ├── timing.json
│           └── grading.json
└── discoverability/
    ├── queries.json
    └── results.json
```

Use the same structure for every iteration. Add `run-2.txt` and the matching records when you run the second pass. Record `total_tokens` and `duration_ms` for every run in the configuration `timing.json`. Record pass or fail status and concrete evidence for every assertion in `grading.json`.

## Reports

Write these iteration reports:

- `manifest.json`: record version `1`, the skill name, the iteration number, and the complete ordered `case_ids` list.
- `benchmark.json`: record pass rate, token use, duration, and the delta between `with_skill` and `old_skill`.
- `feedback.json`: record human review notes, limitations, and the release recommendation.
- `grading-summary.json`: aggregate assertion results for every case and configuration.

Use `ai:skills:evals:prepare` after each specification change. Use a new iteration number to preserve earlier results.

Remove assertions that pass in both configurations. Investigate assertions that fail in both configurations. Treat large token or time increases as an explicit trade-off. Do not ship a behavior change without an improvement over the baseline or a documented reason to accept the trade-off.

## Discoverability evaluation

Run discoverability evaluation when the skill description or routing wording changes. Store the query set and results under `.agents/eval-workspaces/<skill-name>/discoverability/`.

Use about twenty realistic queries. Include prompts that must trigger, prompts that must not trigger, and prompts that test routing against overlapping skills. Split the queries into fixed training and validation sets. Run each query at least three times. Measure trigger rates with the same threshold for all iterations. Change selector wording from training failures only. Choose the version with the best validation result.

## Validation

Run these commands from the repository root:

```bash
mise run ai:skills:evals:validate
mise run ai:skills:validate-conflicts
mise run mise:tasks:validate-conflicts
mise run lint-skill-index --base-path home
mise run check
```

The evaluation validator checks the JSON shape, case IDs, local workspace location, required iteration reports, and accidental symlinks. The conflict validator checks local skill and task names against global names. Fix validation errors before reviewing benchmark results.
