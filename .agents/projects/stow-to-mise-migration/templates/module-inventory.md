# Module Inventory: `<module>`

## Metadata

- Module key: `<module>`
- Story key: `MIG-<id>`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/<module>.md`
- Current declaration: `<path or none>`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.<module>.toml`
- Current owner: `<stow|mise|script|none|mixed>`
- New owner: `<mise|stow|none>`
- Target root: `<path or none>`
- Mise mode: `<symlink|symlink-each|template|bootstrap|none>`
- Environment selector: `<module|profile|none>`
- Dependencies: `<story keys or none>`
- Approval state: `<pending|approved>`
- Inventory status: `incomplete`

## Scope manifest

| Source path | Tracked       | Ignored       | Current owner | Current target   | Target disposition                                         | New source path  | New target       | New mode         | Notes      |
| ----------- | ------------- | ------------- | ------------- | ---------------- | ---------------------------------------------------------- | ---------------- | ---------------- | ---------------- | ---------- |
| `<path>`    | `<yes or no>` | `<yes or no>` | `<owner>`     | `<path or none>` | `<migrate, preserve, remove, repository-only, or unknown>` | `<path or none>` | `<path or none>` | `<mode or none>` | `<reason>` |

## Local and runtime inventory

| Path     | Exists        | Tracked       | Ignored       | Current location           | Active use evidence  | Classification                                                                | Required action                                               | Runtime destination | Metadata to preserve                | Secret or sensitive data |
| -------- | ------------- | ------------- | ------------- | -------------------------- | -------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------- | ----------------------------------- | ------------------------ |
| `<path>` | `<yes or no>` | `<yes or no>` | `<yes or no>` | `<repo, target, or other>` | `<evidence or none>` | `<active-global, active-repo-only, stray, mixed, unknown, or not-applicable>` | `<move, copy-then-erase, preserve, remove, exclude, or none>` | `<path or none>`    | `<mode, owner, group, permissions>` | `<yes, no, or unknown>`  |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

Treat `.DS_Store` as auto-generated macOS metadata. Exclude it from source and
target rows by default. It must not block removal of an approved source
directory unless active use is proven.

## Ownership and cutover

- Current target shape: `<whole-directory symlink|per-file links|physical directory|missing|other>`
- Current target manifest path: `<path>`
- Old owner cleanup command: `<exact command>`
- New owner dry-run command: `<exact command>`
- New owner apply command: `<exact command>`
- Duplicate-owner check: `<exact check>`
- Target-content disposition check: `<exact check>`
- Relative-link check: `<exact check>`

## Coupling

- Scripts:
  - `<path and required change>`
- Environment variables:
  - `<name and source>`
- Includes or external paths:
  - `<path or none>`
- Other modules:
  - `<module and dependency>`
- User-facing behavior:
  - `<behavior to preserve or intentional change>`

## Validation

- Syntax or source checks:
  - `<command>`
- Focused test:
  - `<path>`
- Target smoke test:
  - `<command or deferred reason>`
- Security or token check:
  - `<command>`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `<source, target, manifest, or backup>`
- Rollback dry run:
  - `<command>`
- Rollback apply:
  - `<command>`
- Stop condition:
  - `<condition>`

## Findings and decisions

- Decision: `<approved|deferred|remove|preserve|blocked>`
- Decision evidence:
  - `<path or command result>`
- Residual risk:
  - `<risk or none>`
- Open blocker:
  - `<blocker or none>`
