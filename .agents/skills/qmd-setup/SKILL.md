---
name: qmd-setup
description: Set up QMD in a repository with repository scanning, collection planning, YAML-defined collections, and approval-gated execution. Use when I need local markdown indexing/search initialized or adjusted.
---

# QMD Repository Setup

Use this skill when a repository needs local QMD indexing and search.
Assume `qmd` is already globally available on PATH before running this workflow.

## Setup Flow

1. Scan the repository first to understand structure and identify likely collection roots before running any QMD setup commands.
2. Draft a proposed collection plan and present it to me for review. Include candidate collection paths, collection names, a proposed `context` (description) value for each collection, and any exclusions you expect to apply.
3. Interview me to validate and refine the plan. Ask focused follow-up questions until collection scope, naming, and exclusions are settled.
4. Wait for explicit approval before executing setup. Do not run `qmd init`, `qmd update`, or `qmd embed` until I approve the plan.
5. Run `qmd init` at the target repository root to create the local QMD index defaults (`.qmd/index.yml`, `.qmd/index.sqlite`).
6. Ensure SQLite sidecar files are ignored at the repository root by adding `*.sqlite-shm` and `*.sqlite-wal` to `.gitignore` (create the file if it does not already exist).
7. Register approved content roots by writing the approved collection definitions to `.qmd/index.yml` with repository-relative paths only (for example, `docs` instead of `/full/path/to/repo/docs`) and the approved `context` value for each collection, then confirm the resolved collections with `qmd collection list`.
8. Configure MCP by adding the QMD MCP server entry to a local `.mcp.json` in the repository root. Use the configuration guidance in [`references/mcp-setup.md`](references/mcp-setup.md) and ensure the configured command is `qmd mcp`.

## References

- `qmd-usage` skill
- [`references/mcp-setup.md`](references/mcp-setup.md)
- [QMD README](https://github.com/tobi/qmd#readme)
