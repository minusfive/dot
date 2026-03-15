---
name: project-overview
description: Framework for discovering project structure, architecture, and tooling before making changes.
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

- Check for `Brewfile` and use it for package operations when present.
- Check for mise config files (`mise.toml`, `.config/mise/config.toml`) and use them for runtime/tool versions when present.
- Detect commit message rules from `commitlint.config.*`, `.commitlintrc*`, or `package.json` `commitlint` settings.

## Output Expectations

- Summarize discovered conventions before editing code.
- Call out missing or conflicting conventions and choose the safest default.
- Reference related skills explicitly when needed (for example, `scripts` skill or `commit-guidelines` skill).
