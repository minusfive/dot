---
name: qmd-local-setup
description: Configure and use QMD in a repository with native commands (`qmd init`, `qmd collection ...`, `qmd update`, `qmd embed`, `qmd query`). Use when setting up or operating local markdown indexing/search with QMD.
---

# QMD Local Repository Setup

Use this skill when a repository needs local QMD indexing and search.

## Setup Flow

1. Run `qmd init` at the target repository root to create the local QMD index defaults (`.qmd/index.yml`, `.qmd/index.sqlite`).
2. Register content roots with native collection commands:
   - `qmd collection add <path> --name <collection>`
   - `qmd collection list`
3. Build and refresh the index with native commands:
   - `qmd update`
   - `qmd embed`
4. Query using native QMD commands:
   - `qmd query <query>`
   - `qmd search <query>`
   - `qmd get <doc-or-path>`
5. Verify repository index health with native inspection commands:
   - `qmd status`
   - `qmd ls`
   - `qmd doctor`

Keep `.qmd/` artifacts as normal local repository data unless I explicitly ask you to change ignore behavior.

## References

- [QMD README](https://github.com/tobi/qmd#readme)
- [QMD CLI syntax and query grammar](https://github.com/tobi/qmd/blob/main/docs/SYNTAX.md)
- [QMD agent skill docs](https://github.com/tobi/qmd/tree/main/skills/qmd)
