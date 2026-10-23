---
name: mise-bootstrap-zsh
description: Use when changing Zsh startup files, numbered startup sections, mise-managed shell blocks, path order, or Zsh bootstrap tests.
---

# Mise Bootstrap Zsh

Use this skill when a `mise` module changes how Zsh starts or manages part of a startup file.

## Startup layout

- Keep `home/.config/zsh/.zshrc` limited to the unique-array declarations and the lines that load the numbered startup files.
- Load the startup files in this order:
  - Zone 0: machine setup and path setup.
  - Zone 1: shell framework setup.
  - Zone 2: user choices, editor settings, and prompt hooks.
  - Zone 3: tool integrations.
- Give each module one named block and one source file for each block.

## Ordering and ownership

- Put all other startup code in a numbered startup file.
- Put each prompt hook in the zone 2 block of the module that provides it.
- Put each environment or tool choice in the zone 2 block of the module that provides it.
- Put each package path entry in that package's module, not in the shared Zsh source file.
- Add package paths at the front with `path=(<entry> $path)`.
- When moving a module block between zones, keep its source snippet filename stable unless its ownership or purpose changes.
- Preserve accurate source comments when a repository implementation detail changes.
- Keep local paths after package paths in the base startup block.
- Keep `typeset -aU path`, `typeset -aU fpath`, and `typeset -aU manpath` at the top of `~/.config/zsh/.zshrc`.
- When a source file is both a `symlink-each` source and a block source, exclude it from the linked files.
- Keep the existing startup-file order when you add a module. Do not depend on accidental file order.

## Validation

- Run `zsh -n` on every changed Zsh source file.
- Run the module contract test for changed declarations and the focused test for changed Zsh behavior.
- Preview both work and personal bootstrap plans.
- Run `mise run fix` after focused tests pass.
- Run the aggregate checks before completion.
