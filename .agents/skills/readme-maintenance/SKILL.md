---
name: readme-maintenance
description: Keep a repository README current, educational, and accurate when setup, layout, ownership, tooling, architecture, or workflows change. Use when updating README.md or deciding whether a repository change needs README documentation.
---

# README Maintenance

Use `README.md` as the human-facing guide. Keep it clear, educational, and focused on repository purpose, setup, structure, ownership, and workflows.

## Tool and package names

Keep README content general. Name a tool, package, application, package manager, extension, or configuration component only from the approved list. Use general terms when a specific name is not needed. Ask me before adding another name; that approval applies only to the current change unless I add it to the list.

Wrap each named tool, package, application, operating system, or other technical noun in single backticks, including linked text.

Approved names:

- `Git`
- `Hammerspoon`
- `Homebrew`
- `hk`
- `macOS`
- `mise`
- `Neovim`
- `Nix`
- `ProfileState Spoon`
- `WezTerm`
- `Zsh`

Treat repository-internal module names, environment variable names, config keys, exact target paths, and source filenames as implementation details. Do not add them to README unless readers must use them for setup or must understand an ownership boundary. When an internal detail matters, describe the behavior or ownership in general terms and update existing prose instead of adding a duplicate paragraph.

## When to update

Update `README.md` when a change affects:

- The repository purpose, supported environment, setup, bootstrap, or development workflow.
- The source-tree layout, target path, or ownership between mise, scripts, and an application.
- A primary tool, configuration surface, migration state, compatibility boundary, link, command, or user-facing statement.

Do not change `README.md` for internal refactors that do not affect what readers install, configure, run, or need to understand.

## Authoring workflow

1. Read the complete `README.md`, the change diff, and the files that define the changed behavior.
2. Update the smallest section that explains the reader-facing change and its reason.
3. Explain what a component does before explaining how to use it.
4. Load `writing-style`, then `simple-english`, before drafting or reviewing README prose.
5. Keep explanatory README sections, including profile, architecture, ownership, and workflow overviews, descriptive and neutral. State facts about choices and effects instead of telling readers what to choose or do. Reserve imperative wording for explicit setup steps and commands. Put operational directives for agents or contributors in instruction files, not in README explanations.
6. Use plain language for readers who do not know the repository internals. Avoid jargon, buzzwords, unexplained abbreviations, and internal terms. Keep technical terms only when readers need them, and explain them at first use.
7. Use short paragraphs, clear headings, lists for separate facts, and one source line per paragraph.
8. Use repository-relative links for tracked files and canonical links for external tools.
9. Put a tool link beside its first mention. Remove stale commands, paths, links, and claims.
10. Keep profile descriptions general and omit personal package or cask examples unless setup requires them.
11. Run a full critique cycle with `critique-workflow` before running checks. Resolve its findings and finalize the edit.
12. Run checks against the final README edit before declaring the README update complete.

## Final checklist

- The README matches the current setup commands, paths, links, ownership, and workflow.
- The layout and ownership model are clear to a new contributor.
- Each approved primary tool has a concise purpose and a canonical link.
- The README explains current behavior instead of copying operational procedures.
