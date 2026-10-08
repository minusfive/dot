---
name: preview-docs
description: Manage Markdown preview servers with the global md:preview task. Use when asked to list, start, select, refresh, reconcile, or stop preview docs or preview servers.
---

# Preview Docs

Use the global `md:preview` task for Markdown preview lifecycle operations.

Use the task's live help for its arguments, options, defaults, and output formats. Follow `mise-tasks` for task help or discovery.

## List running previews

List running preview servers with the task.

Return the task output without parsing or reformatting it.

## Manage previews

- Start a preview for a Markdown file.
- Select a Markdown file from a directory.
- Refresh the matching preview.
- Reconcile stale or duplicate previews.
- Stop all preview servers when requested.

Let the task own preview-state parsing and lifecycle details.
