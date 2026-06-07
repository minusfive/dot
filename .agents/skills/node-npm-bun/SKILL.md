---
name: node-npm-bun
description: Guide Node package-manager execution across bun, npm, and bunx/npx. Use when installing dependencies, running scripts, or invoking Node CLIs, while preferring bun/bunx when available and respecting project standards.
---

# Node / npm / bun

Use this skill for Node.js dependency management, script execution, and CLI invocation in repositories that use JavaScript or TypeScript tooling.

## Decision Order

1. Respect the project's declared tooling and standards first.
2. When the project does not declare a package-manager standard, prefer `bun` and `bunx` when available.
3. Fall back to npm tooling (`npm` / `npx`) only when bun is unavailable or unsuitable for the task.

## Project-Standards Detection

- Detect project standards from `package.json` (`packageManager`), lockfiles, CI config, repository docs, and existing task scripts.
- Follow explicit user direction when they ask for a specific package manager.
- Keep the existing package-manager workflow consistent across the task; do not mix managers in a way that introduces churn.

## Command Rules

- Dependency install:
  - Preferred default: `bun install`
  - Project-standard fallback: use the project's existing manager command (`npm install`, `pnpm install`, `yarn install`, etc.).
- Script execution:
  - Preferred default: `bun run <script>`
  - Project-standard fallback: use the project's existing script runner form.
- One-off CLIs:
  - Preferred default: `bunx <command>`
  - Fallback: `npx <command>` when bun is unavailable.

## Safety and Consistency

- Do not add or change lockfiles solely to switch package managers.
- When project standards conflict with bun preference, prioritize project standards.
- Preserve existing repository conventions for script names, lifecycle hooks, and task entrypoints.
