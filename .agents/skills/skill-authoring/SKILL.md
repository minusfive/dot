---
name: skill-authoring
description: Create, modify, audit, and validate agent skills. Use whenever skill definitions or skill behavior are being changed.
user-invocable: true
disable-model-invocation: false
---

# Skill Authoring

Use this skill for any skill manipulation task.

## Mandatory Spec Intake

At the start of each skill task, load these references in this exact order:

1. [Agent Skills specification](https://agentskills.io/specification)
2. [Claude Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
3. [GitHub Copilot CLI skill docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)

Use the loaded specs as the active source of truth for the task.
Avoid static assumptions and derive requirements dynamically from the loaded references and current repository state.

## Validation and Auditing

- Validate skill metadata, structure, and behavior against the loaded specs.
- Use markdown links (`[text](url)`) instead of bare URLs so skill docs pass markdownlint (`MD034/no-bare-urls`).
- Audit for duplicate or conflicting instructions across instruction sources (for example: `AGENTS.md`, `CLAUDE.md`, `COPILOT.md`, repository instruction files, and other skill files).
- Prefer a single canonical source and cross-reference it rather than duplicating the same guidance.
- For planning-phase completeness policy, use `planning` as canonical and keep related skills as references.
- Flag or remove drift-prone duplication that can diverge from real behavior over time.
