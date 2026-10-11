---
name: agentic-projects
description: Organize hidden or promoted per-repo agentic project workspaces. Use when creating, moving, maintaining, or promoting project prompts, plans, research, and temporary artifacts.
allowed-tools: Bash(bash ~/.agents/skills/agentic-projects/scripts/manage-agentic-project.sh)
metadata:
  scripts: scripts/manage-agentic-project.sh
---

# Agentic Projects

Manual trigger only.

Run the colocated script to initialize or update:

`.agents/projects.local/<project-name>/`

## Workspace contents and usage

- `PROMPT.md`: canonical project prompt + working instructions for you.
- `plans/<plan-name>.md`: one file per plan iteration or variant. Use for persisted planning history and persisted subagents orchestration synchronization artifacts.
- `research/<research-item-name>.md`: one file per research artifact or finding.
- `tmp/`: ephemeral artifacts (large outputs, reusable temp scripts, intermediate data, non-persisted subagents orchestration synchronization artifacts). Delete contents when project is complete.

## Version control

- Create hidden projects under `.agents/projects.local/<project-name>/` by default. The global Git ignore rule excludes this directory.
- Promote a project for check-in by moving it to `.agents/projects/<project-name>/`.
- Keep promoted project files under normal repository and global ignore rules. Do not use `git add -f` for a promoted project.
- Keep `tmp/` out of promoted projects with a project-specific `.gitignore` only when no repository-level rule already excludes it.
- Remove a project-specific `.gitignore` when the project remains under `.agents/projects.local/` and the global rule already excludes the entire project.
- Check in a project only when I explicitly ask you to persist it with the repository.

## Invocation

- Provide project name and initial prompt with:
  - `--project <project-name>`
  - `--prompt "<initial prompt>"` or `--prompt-file <path>`
- Use `--force` only when explicitly overwriting an existing `PROMPT.md`.

The script handles creation of missing directories/files and returns clear errors for invalid input or conflicting state.
