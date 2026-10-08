---
name: lua
description: Apply Lua authoring conventions for Neovim, Hammerspoon, WezTerm, and Yazi configurations. Use when writing, editing, or refactoring Lua modules, plugin configs, or scripts in this repository.
---

# Lua Authoring Conventions

## Module Structure

- Organize `---@module` references at the top of the file, sorted alphabetically.
- Use explicit module returns and clear structure.
- Keep one cohesive responsibility per module; split when a module grows two unrelated concerns.

## Annotations

- Use EmmyLua annotations for public functions, types, and module returns.
- Annotate parameters and return types so downstream tooling (LSP, type checkers) can reason about them.

## Cross-references

- For Neovim-specific patterns (LazyVim plugins, `which-key`, LSP integration) see the `nvim` skill.
- For Hammerspoon-specific patterns (Spoons, modifier keys, window management) see the `hammerspoon` skill.
