---
name: tanstack-cli
description: Use TanStack CLI for app scaffolding, add-on management, docs lookup, and MCP migration whenever a project uses TanStack tools or I ask for TanStack workflows.
---

# TanStack CLI

Use this skill when a repository uses TanStack tooling (for example `@tanstack/*` packages, TanStack Start/Router apps, or a `.tanstack.json` file), or when I ask for TanStack CLI workflows.

## Core Rules

- Prefer TanStack CLI commands for TanStack project scaffolding, add-ons, docs lookup, and ecosystem discovery.
- Prefer `bunx @tanstack/cli ...` unless the environment already provides a working `tanstack` binary.
- Treat any `tanstack ...` examples as command shorthand. When no global `tanstack` binary is present, run the equivalent `bunx @tanstack/cli ...` command.
- Use JSON output (`--json`) for agent-facing introspection and automation commands so output is deterministic.
- Treat Node.js 18+ as a prerequisite for TanStack CLI usage.

## Command Selection

- Create projects with `bunx @tanstack/cli create`.
- Add integrations to existing projects with `bunx @tanstack/cli add`.
- Query available libraries with `bunx @tanstack/cli libraries --json`.
- Read a specific doc page with `bunx @tanstack/cli doc ... --json`.
- Search docs with `bunx @tanstack/cli search-docs ... --json`.
- Discover ecosystem recommendations with `bunx @tanstack/cli ecosystem ... --json`.
- Use `bunx @tanstack/cli pin-versions` when stabilizing TanStack dependency version ranges.

## MCP Migration (Required)

- `tanstack mcp` was removed from TanStack CLI and should not be used.
- Replace MCP-style calls with direct CLI commands:
  - `listTanStackAddOns` -> `bunx @tanstack/cli create --list-add-ons --framework React --json`
  - `getAddOnDetails` -> `bunx @tanstack/cli create --addon-details drizzle --framework React --json`
  - `createTanStackApplication` -> `bunx @tanstack/cli create my-app --framework React --add-ons drizzle,clerk`
  - `tanstack_list_libraries` -> `bunx @tanstack/cli libraries --json`
  - `tanstack_doc` -> `bunx @tanstack/cli doc query framework/react/overview --json`
  - `tanstack_search_docs` -> `bunx @tanstack/cli search-docs "server functions" --library start --json`
  - `tanstack_ecosystem` -> `bunx @tanstack/cli ecosystem --category database --json`
- If a project still references `@tanstack/cli mcp` in MCP client config, remove that reference as part of migration.
- The app-level `mcp` add-on can still be used when a generated application needs to host its own MCP endpoint.

## References

- [TanStack CLI docs](https://tanstack.com/cli/latest)
- [CLI Reference](https://tanstack.com/cli/latest/docs/cli-reference)
- [MCP Migration](https://tanstack.com/cli/latest/docs/mcp-migration)
- [Installation](https://tanstack.com/cli/latest/docs/installation)
