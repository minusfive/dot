# Per-module migration agent prompt

You own one module inventory file:

- Module key: `<module>`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/<module>.md`
- Repository root: `~/dev/personal/dot`
- Inventory template: `.agents/projects/stow-to-mise-migration/templates/module-inventory.md`

## Objective

Inspect the current repository and machine state for `<module>`. Create only
the assigned inventory file. Do not edit any other file, including the
roadmap, other inventories, scripts, configuration, or source files.

Run one module inventory at a time. Follow the story order in the roadmap.
Complete this inventory before starting another module inventory.

## Required evidence

1. Inspect the current declaration, source paths, target paths, and owner.
2. List tracked files with `git ls-files -- <boundary>`.
3. List ignored files with `git ls-files --others --ignored --exclude-standard -- <boundary>`.
4. List non-ignored untracked files with `git ls-files --others --exclude-standard -- <boundary>`.
5. Explain every source and target entry as `migrate`, `preserve`, `remove`,
   `repository-only`, or `unknown`.
6. Inspect target shape with `test`, `readlink`, `stat`, and metadata commands.
7. Inspect scripts, environment variables, includes, and tests that reference
   the module.
8. Record active-use evidence without printing secrets, tokens, databases, or
   credential-bearing file contents.
9. Record the exact dry-run, apply, validation, and rollback commands.
10. Record unresolved risks as blockers. Do not invent missing evidence.

Treat `.DS_Store` as auto-generated macOS metadata. Exclude it from the
inventory, migration scope, and cleanup blockers by default. Do not add a
`.DS_Store` row unless active use is proven.

## Security rules

- Do not print file contents from authentication databases, WAL files,
  credential stores, token-bearing host files, shell history, or private keys.
- Use metadata, file names, references, checksums, and command results instead.
- If a path is mixed, separate relevant local files from stray files.
- If a path is active and repository-only, keep it outside `~/dev/personal/dot/home/`.
- If a path is active globally, define its runtime destination outside the
  repository before the ownership transition.

## Output rules

- Use the exact headings and table columns in the inventory template.
- Keep the inventory self-contained.
- Use repository-relative paths or `~` paths. Do not write machine-specific
  absolute paths.
- Set `inventory status` to `complete` only when every required field has
  evidence.
- Leave `approval state` as `pending`.
- Do not make implementation changes.
