---
name: writing-style
description: Apply shared prose tone and publication-readiness rules across docs and instruction files. Use when drafting, editing, or critiquing RFCs, specs, wiki pages, guides, or other authored content.
---

# Writing Style

Use this skill for authored prose across markdown documentation and instruction files.

## Required workflow

- Invoke `simple-english` immediately after loading `writing-style` and before drafting, revising, or critiquing prose.
- If `simple-english` is not loaded, stop and load it before making prose edits or prose-critique verdicts.

## Core writing rules

- For sentence structure, vocabulary control, and ambiguity reduction, follow `simple-english` as the canonical standard.
- Capitalize organization, team, and program names when used as proper nouns; use lowercase forms when used as generic concepts.
- Wrap technical nouns in single backticks in prose and tables.
- Keep documents publish-ready by default: remove internal process notes, agent-session artifacts, and other draft-only content from final document bodies.
- Match structure to content. Use bullets or numbering for discrete points. Use paragraphs for one connected idea.
- Keep operational behavior directives in instruction files (for example `AGENTS.md` and skill `SKILL.md`) instead of reader-facing document bodies.
- In reader-facing docs, use references the intended audience can actually access. If a public or published URL is not available yet, mark it as pending publication instead of linking private local-only paths.

## Validation

- If `writing-style` is used in a run that edits or critiques authored prose, explicitly verify that `simple-english` was loaded in the same run before finalizing.
