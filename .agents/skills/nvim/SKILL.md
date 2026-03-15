---
name: nvim
description: AI rules and guidelines for the Neovim configuration built on LazyVim with Lua scripting, LSP integration, and plugin management. Use when working with Neovim configuration files, plugins, or Lua modules.
---

# Neovim Configuration - AI Rules and Guidelines

## Plugin Selection

- Search for plugins dynamically; don't rely on trained knowledge for current options
- Ensure LazyVim compatibility
- Require active maintenance and regular updates
- Prefer Lua-based plugins over Vimscript alternatives
- Prefer well-established plugins with good community support
- Minimal startup and runtime performance impact is mandatory

## Configuration Patterns

- Extend existing LazyVim plugins with `optional = true` to avoid conflicts
- Use `opts = function(_, opts)` when merging with existing configuration
- Use `enabled = function()` for conditional loading based on system state
- Register keymaps via `which-key` specs in plugin opts, not standalone `vim.keymap.set` calls
- Use `vim.api.nvim_create_autocmd` with `which-key` for filetype-scoped keymaps

## LSP Integration

- Use Mason for LSP server management when possible
- Configure non-Mason servers with proper fallbacks
- Configure LSP capabilities with the active completion engine

## AI Integration

- Balance AI features with editor responsiveness
- Ensure sensitive code handling follows `security` skill

## Testing and Validation

- Monitor startup time and memory usage with `:Lazy profile`
- Ensure compatibility with LazyVim updates before upgrading
- Make small, testable, reversible changes
