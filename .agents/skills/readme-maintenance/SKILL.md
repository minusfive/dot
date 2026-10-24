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
- The source-tree layout, target path, or which component manages a resource.
- A primary tool, configuration method, migration state, compatibility, link, command, or other user-facing statement.

Leave `README.md` unchanged for internal refactors that do not affect what readers install, configure, run, or need to understand.

## Authoring workflow

1. Read the complete `README.md`, the complete diff for the requested change, and every file, command, or test that defines the changed behavior. Treat existing README claims as unverified.
2. Decide whether the change affects readers. If it does not affect setup, layout, ownership, tools, workflow, or another user-facing fact, leave `README.md` unchanged and record the reason.
3. Verify each changed claim against the final behavior. Check commands, paths, links, flags, ownership, and migration status. Remove or rewrite stale claims.
4. Update the smallest section that explains the reader-facing change and its reason.
5. Explain what a component does before explaining how to use it.
6. Load `writing-style`, then `simple-english`, before drafting or reviewing README prose.
7. Keep explanatory README sections, including profile, architecture, ownership, and workflow overviews, descriptive and neutral. State facts about choices and effects instead of telling readers what to choose or do. Reserve imperative wording for explicit setup steps and commands. Put operational directives for agents or contributors in instruction files, not in README explanations.
8. Use plain, concrete language for readers who do not know the repository internals. Explain required technical terms at first use. Replace process jargon and negative framing with the reader-facing fact or action, except when a limitation or warning is necessary.
9. Use short paragraphs, clear headings, and lists for separate facts. Keep each paragraph focused on one idea.
10. Use repository-relative links for tracked files and canonical links for external tools. Put a tool link beside its first mention.
11. Keep profile descriptions general and omit personal package or cask examples unless setup requires them.
12. Review the complete final diff, not only the README hunk. Run a fresh `critique-workflow` pass, resolve its findings, and then run checks against the final files. If the critique finds an issue, fix it and repeat the critique before checks.

## Final checklist

- The README matches the current setup commands, paths, links, ownership, and workflow.
- Every changed user-facing claim matches the final behavior.
- The layout and ownership model are clear to a new contributor.
- Each approved primary tool has a concise purpose and a canonical link.
- The README explains current behavior instead of copying operational procedures.
- The complete final diff was reviewed, the critique findings were resolved, and the final checks passed.
