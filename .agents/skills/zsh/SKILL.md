---
name: zsh
description: Apply Zsh shell scripting conventions for error safety and logging. Use when authoring, modifying, or reviewing Zsh scripts, including mise file tasks and bootstrap scripts.
---

# Zsh Scripting Conventions

## Error Safety

- Use `set -euo pipefail` at the top of every Zsh script to fail fast on errors, undefined variables, and broken pipes.

## Logging

- Use consistent logging functions across scripts in the same project; detect and reuse existing helpers before introducing new ones.

## Cross-references

- For broader script-authoring guidance (project pattern detection, environment configuration, testing, integration) see the `scripts` skill.
- For mise-specific task authoring (file tasks, TOML tasks, usage directives) see the `mise-tasks` skill.
