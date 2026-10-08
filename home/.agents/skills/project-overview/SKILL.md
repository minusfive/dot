---
name: project-overview
description: Discover project structure, architecture, and tooling before implementation. Use when starting work in an unfamiliar repository or before making non-trivial code changes.
---

# Project Overview

Use this skill to map how a project is organized before implementation.

## Discovery Checklist

- **Entry points**: identify primary application startup, build, and bootstrap scripts.
- **Package management**: detect package manifests and lock files.
- **Runtime/tool versioning**: detect version manager configs.
- **Testing and linting**: locate test commands, linter configs, and CI workflows.
- **Automation scripts**: locate reusable scripts and task runners.
- **Documentation**: find contributor docs, architecture docs, and operational runbooks.

## Configuration Detection Priorities

- For package/runtime environment detection rules, follow the canonical guidance in `scripts` skill.
- For commit message rule discovery (`commitlint`/Conventional Commits), follow the canonical guidance in `commit-guidelines` skill.

## Output Expectations

- Summarize discovered conventions before editing code.
- Call out missing or conflicting conventions and choose the safest default.
- Surface unresolved ambiguities as a numbered list of explicit questions.
- Do not carry unresolved ambiguities into execution.
- Reference related skills explicitly when needed (for example, `scripts` skill or `commit-guidelines` skill).
