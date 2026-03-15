---
name: hammerspoon
description: AI rules and guidelines for Hammerspoon macOS automation and window management configuration using Lua scripting. Use when working with Hammerspoon scripts, Spoons, hotkeys, or window management code.
---

# Hammerspoon Configuration - AI Rules and Guidelines

## Modifier Keys

- **meh**: `cmd + alt + ctrl` — primary modifier for normal hotkeys
- **hyper**: `cmd + alt + ctrl + shift` — secondary modifier for modal triggers and sticky modals

## Spoon Development

- Keep Spoons focused on a single responsibility
- Implement all four lifecycle methods: `init()`, `start()`, `stop()`, `bindHotkeys()`
- Return `self` from lifecycle methods for chaining
- Store configuration in an `options` table
- Use EmmyLua annotations for all Spoons and public functions
- Use `hs.logger` for log messages
- Clean up all resources (watchers, timers) in `stop()`
- Handle errors with `pcall`; log failures via `hs.logger`

## Hotkey Patterns

- **Normal hotkeys**: use `meh` modifier for frequently accessed, instant-access functions
- **Modal one-shot** (`isOneShot = true`): exits modal after single action — use for quick grouped actions
- **Modal sticky** (`isOneShot = false`): stays active until manually exited — use for workflow sequences
- Document bindings that depend on a custom keyboard layout with a comment linking to the layout config

## Window Management

- Define layouts as `---@enum (key)` annotated tables of unit rectangles (0-1 scale)
- Guard `hs.window.focusedWindow()` calls — may return `nil`
- Set `hs.window.animationDuration = 0` for snappy movements
- Use `hs.window.filter` for window watching instead of polling
- Avoid blocking operations in hotkey callbacks

## Testing and Validation

- Reload with `hs.reload()` for immediate feedback
- Verify hotkeys don't conflict with system or application shortcuts
- Test window movements across multiple displays
- Validate modal states exit correctly
- Monitor Hammerspoon console for errors
