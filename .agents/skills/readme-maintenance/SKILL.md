---
name: readme-maintenance
description: Keep a repository README current, educational, and accurate when setup, layout, ownership, tooling, architecture, or workflows change. Use when updating README.md or deciding whether a repository change needs README documentation.
---

# README Maintenance

## Purpose

Treat `README.md` as the human-facing entry point for this repository.

- Explain what the repository manages and how its main parts work together.
- Explain the reasons for important ownership, layout, and migration choices.
- Give a concise reference to the primary tools, with a short description and a link to each tool.
- Show the source-tree layout when it helps a reader find or understand a managed file.
- Keep setup and development guidance accurate enough for a reader to start work.

Keep `README.md` focused on reader-facing setup, repository understanding, and workflows.

## Update triggers

Update `README.md` in the same change when a change affects:

- The repository purpose or supported environment.
- Setup, bootstrap, initialization, or development commands.
- The source-tree layout or the target path of a managed file.
- Ownership between mise, GNU Stow, scripts, or an application.
- The primary tools or the role of a tool in the workflow.
- A migration state, compatibility boundary, or user-facing workflow.
- A link, image, command, or statement that the change makes inaccurate.

Do not add README churn for internal refactors that do not change what readers install, configure, run, or need to understand.

## Structure

Keep the README structure easy to scan:

1. Open with the repository purpose and the main tools.
2. Explain the workflow context that readers need.
3. Give setup steps and the safety context for commands that change a machine.
4. Explain global files, source-tree layout, and ownership.
5. Describe the primary programs and configuration surfaces.
6. Describe the development workflow.

Add a focused section when new information does not fit these topics. Keep related facts together, and explain one main topic per paragraph.

## Writing rules

- Use an educational, descriptive tone.
- Explain what a component does before you explain how to use it.
- State why a non-obvious design exists when the reason helps a reader make a safe change.
- Use repository-relative links for tracked files and canonical links for external tools.
- Put a tool link beside its first mention, then use one consistent name.
- Keep commands in code blocks and explain their effect before or after the block.
- Use short paragraphs, clear headings, and lists for separate facts.
- Remove stale commands, paths, links, and migration statements when the source changes.
- Keep the README concise. Link to canonical tool documentation instead of copying it.

## Workflow

1. Read the complete `README.md` and the change diff.
2. Read the repository files that define the changed behavior.
3. Decide whether a reader's setup, understanding, or workflow changes.
4. Update the smallest README section that explains the change and its reason.
5. Check every changed path, command, link, image, and tool description against the repository.
6. Inspect the complete diff and run the checks that cover the changed README content.

## Critique

- Check that the README explains the current repository behavior, not only the latest change.
- Check that the layout and ownership model remain understandable to a new contributor.
- Check that each primary tool has a concise purpose and a canonical link.
- Check that setup commands and repository paths still match the source.
- Check that the README stays focused on reader-facing setup, repository understanding, and workflows.
