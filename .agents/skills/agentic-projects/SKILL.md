---
name: agentic-projects
description: Organize per-repo agentic project workspaces under .agents/projects/<project-name>. Use when initializing or maintaining project prompt, plans, research, and temporary artifacts.
user-invocable: true
disable-model-invocation: true
argument-hint: --project <project-name> --prompt "<initial prompt>" [--force]
allowed-tools: Bash(bash ~/.agents/skills/agentic-projects/scripts/manage-agentic-project.sh)
metadata:
  scripts: scripts/manage-agentic-project.sh
---

# Agentic Projects

Manual trigger only.

Run the colocated script to initialize or update:

`.agents/projects/<project-name>/`

## Workspace contents and usage

- `PROMPT.md`: canonical project prompt + working instructions for the agent.
- `plans/<plan-name>.md`: one file per plan iteration or variant. Use for persisted planning history and persisted subagents orchestration synchronization artifacts that should be versioned.
- `research/<research-item-name>.md`: one file per research artifact or finding.
- `tmp/`: ephemeral artifacts (large outputs, reusable temp scripts, intermediate data, non-persisted subagents orchestration synchronization artifacts). Delete contents when project is complete.
- `.gitignore`: ignores `tmp/*` so temporary artifacts are not committed.

## Invocation

- Provide project name and initial prompt with:
  - `--project <project-name>`
  - `--prompt "<initial prompt>"` or `--prompt-file <path>`
- Use `--force` only when explicitly overwriting an existing `PROMPT.md`.

The script handles creation of missing directories/files and returns clear errors for invalid input or conflicting state.
