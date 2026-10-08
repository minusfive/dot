---
name: opencode-copilot-multipliers
description: Sync GitHub Copilot model alias names in OpenCode config with current paid multipliers from github/docs. Use when asked to refresh or update OpenCode Copilot alias multiplier labels.
allowed-tools: Bash(bun ~/.agents/skills/opencode-copilot-multipliers/scripts/sync-opencode-copilot-multipliers.ts)
metadata:
  scripts: scripts/sync-opencode-copilot-multipliers.ts
---

# OpenCode Copilot Multipliers

Use this skill to refresh `provider.github-copilot.models.*.name` labels in OpenCode config from the current model-multiplier source table.

## Workflow

1. Run the colocated sync script defined in this skill metadata.
2. Review the script output table of planned updates, additions, and removals.
3. Review the diff and ensure only provider model override labels changed.
