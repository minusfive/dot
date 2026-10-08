---
name: markdown
description: Apply global Markdown authoring conventions. Use when working with Markdown files.
---

# Markdown Authoring Conventions

## Style

- Write clearly and succinctly.
- Use fenced code blocks with explicit language identifiers for structured examples (for example `json`, `yaml`, `graphql`, and `bash`).
- Use standard `[text](url)` links; do not use wiki-style links.
- Replace redundant or duplicated content with link references to a single canonical location.
- Prefer lists over tables. Use a table only when readers genuinely need to scan multiple parallel attributes across many rows; otherwise present the same content as a bulleted or definition list, which renders more reliably in narrow viewports, plain-text diff tools, and screen readers.

## Table of Contents

- Create a table of contents only when explicitly requested.
- When a table of contents exists, keep it synchronized with the actual section headings.

## Validation

- Validate all reference links after changes; fix dangling or moved targets.
- Analyze the whole file and apply these rules consistently; flag deviations.
- For Markdown lint execution policy, follow the `linting` skill.
