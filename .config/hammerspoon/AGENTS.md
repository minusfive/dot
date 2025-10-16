# Hammerspoon Configuration - AI Rules and Guidelines

Powerful macOS automation and window management system built with Hammerspoon. Core technologies: Hammerspoon, Lua scripting, custom Spoons, hotkey management, window manipulation.

## READ FIRST: MANDATORY Rules and Guidelines

**You MUST follow everything stipulated on the [main AGENTS.md](../../AGENTS.md) file first and foremost**. That file **SUPERSEDES** any seemingly contradictory language found on this file or anywhere else.

If you detect any such contradictions, you **MUST** report them so they can be resolved.

## Hammerspoon Configuration Overview

### Directory Structure

```sh
.config/hammerspoon/        # Hammerspoon configuration root
├── init.lua                # Main entry point and configuration
├── Spoons/                 # Custom Spoon modules
│   ├── AppLauncher.spoon/  # Application launching utilities
│   │   └── init.lua
│   ├── Caffeine.spoon/     # System sleep prevention
│   │   └── init.lua
│   ├── EmmyLua.spoon/      # LSP type annotations
│   │   ├── annotations/
│   │   ├── docs.json
│   │   └── init.lua
│   ├── Hotkeys.spoon/      # Hotkey and modal management
│   │   └── init.lua
│   └── WindowManager.spoon/ # Window positioning and manipulation
│       └── init.lua
└── .luarc.json            # Lua LSP configuration
```

### Architecture Overview

- **Entry Point**: `init.lua` loads Spoons and configures hotkeys/modals
- **Spoon System**: Modular architecture with self-contained functional units
- **Hotkey Management**: Two-tier system with normal and modal hotkeys
- **Window Management**: Precise window positioning using unit rectangles
- **App Launching**: Fast application switching with hotkeys
- **Type Safety**: EmmyLua annotations for LSP support and type checking

### Core Knowledge Requirements and Technology Stack

- Lua programming language and Hammerspoon API
- macOS window management and accessibility APIs
- Hotkey and modal system design patterns
- Spoon architecture and lifecycle methods
- Unit rectangle geometry for window positioning
- EmmyLua type annotations for IDE support
- macOS application launching and focus management

### Key Components

- **WindowManager**: Grid-based window positioning with predefined layouts (1/2, 1/3, 1/4, 2/3 splits)
- **AppLauncher**: Application launching with focus handling for special cases
- **Hotkeys**: Modal and normal hotkey management with one-shot and sticky modes
- **Caffeine**: System sleep prevention toggle
- **EmmyLua**: Type annotations and LSP documentation

### Hammerspoon-Specific Analysis Commands

Use systematic exploration patterns for Hammerspoon configurations:

- `eza --tree --level=2 .config/hammerspoon/` - Overview of structure
- `cat .config/hammerspoon/init.lua` - Main configuration and hotkey bindings
- `cat .config/hammerspoon/Spoons/*/init.lua` - All Spoon implementations
- `head -100 .config/hammerspoon/Spoons/WindowManager.spoon/init.lua` - Window manager patterns

## Hammerspoon-Specific Coding Guidelines

### Lua Configuration Standards

Follow [main AGENTS.md Lua guidelines](../../AGENTS.md#lua-neovim-hammerspoon-wezterm-yazi).

### Modifier Keys Reference

Standard modifier key combinations used throughout configuration:

- **meh**: `cmd + alt + ctrl` - Primary modifier for normal hotkeys
- **hyper**: `cmd + alt + ctrl + shift` - Secondary modifier for alternative hotkeys and sticky modals

### Type Annotations with EmmyLua

Use EmmyLua annotations for all Spoons and public functions. See [Spoon Structure](#spoon-structure) for complete example.

### Window Unit Rectangles

Define layouts as normalized unit rectangles (0-1 scale):

```lua
-- filepath: .config/hammerspoon/Spoons/WindowManager.spoon/init.lua
---@enum (key) WindowManager.layout
WindowManager.layout = {
  left50 = { x = 0, y = 0, w = 0.5, h = 1 },
  right50 = { x = 0.5, y = 0, w = 0.5, h = 1 },
  center33 = { x = 0.3333, y = 0, w = 0.3333, h = 1 },
}
```

### Hammerspoon Testing and Validation

Follow [main AGENTS.md Testing and Validation](../../AGENTS.md#testing-and-validation), plus:

- Test changes with `hs.reload()` for immediate feedback
- Verify hotkeys don't conflict with system or application shortcuts
- Test window movements across multiple displays
- Validate modal states exit correctly
- Monitor Hammerspoon console for errors and warnings
- Test with target applications running and focused

## Spoon Development Guidelines

### Spoon Structure

Follow standard Spoon architecture with complete type annotations:

```lua
-- filepath: .config/hammerspoon/Spoons/Example.spoon/init.lua
---@class Example
---@field name string
---@field version string
---@field author string
---@field license string
---@field options ExampleOptions
local Example = {
  name = "Example",
  version = "0.1",
  author = "...",
  license = "MIT",

  ---@class ExampleOptions
  options = {
    enabled = true,
  },
}

---Initialize the Spoon
---@return Example
function Example:init()
  return self
end

---Start the Spoon
---@return Example
function Example:start()
  -- Setup watchers, timers, etc.
  return self
end

---Stop the Spoon
---@return Example
function Example:stop()
  -- Cleanup resources
  return self
end

---Optional: Bind hotkeys for this Spoon
---@param mapping table<string, table>
---@return Example
function Example:bindHotkeys(mapping)
  -- Setup hotkey bindings
  return self
end

return Example
```

### Lifecycle Methods

- **init()**: Called when Spoon is loaded, setup internal state
- **start()**: Called to activate Spoon functionality (watchers, timers, etc.)
- **stop()**: Called to deactivate and cleanup resources
- **bindHotkeys()**: Optional method for hotkey binding configuration

### Spoon Best Practices

- Keep Spoons focused on a single responsibility
- Return `self` from lifecycle methods for method chaining
- Document all public methods with EmmyLua annotations
- Store configuration in `options` table
- Use meaningful log messages with `hs.logger`
- Handle errors gracefully and log them
- Clean up all resources in `stop()` method

### Error Handling

```lua
-- filepath: .config/hammerspoon/Spoons/Example.spoon/init.lua
function Example:start()
  local success, result = pcall(function()
    -- Potentially failing operation
  end)

  if not success then
    hs.logger.new(self.name, "error"):e("Failed to start: " .. result)
    return self
  end

  return self
end
```

### Hotkey Management Patterns

Hammerspoon supports two types of hotkeys: normal (direct) and modal (grouped). Use the appropriate pattern based on access frequency and logical grouping.

#### Normal (Non-Modal) Hotkeys

Use for frequently accessed functions requiring instant access:

```lua
-- filepath: .config/hammerspoon/init.lua
---@type hs.hotkey.KeySpec[]
local normalSpecs = {
  -- Application launches with meh modifier
  { hk.mods.meh, "t", "WezTerm", al:openApp("WezTerm") },
  { hk.mods.meh, "e", "Microsoft Outlook", al:openApp("Microsoft Outlook") },

  -- Window positioning with hyper modifier
  { hk.mods.hyper, "7", "1/2 Left", wm:move(wm.layout.left50) },
  { hk.mods.hyper, "8", "1/2 Center", wm:move(wm.layout.center50) },
}

-- Bind normal hotkeys
hk:bindHotkeys({ specs = normalSpecs })
```

#### Modal Hotkeys - One-Shot Mode

Use for actions that should exit the modal immediately after execution. Ideal for quick, single actions from a related group:

```lua
-- filepath: .config/hammerspoon/init.lua
---@type Hotkeys.ModalSpec
local modeAppLauncherOneShot = {
  trigger = { hk.mods.meh, "tab", "App Launcher" },
  isOneShot = true,
  specs = {
    { {}, "a", "App Store", al:openApp("App Store") },
    { {}, "d", "Discord", al:openApp("Discord") },
    { {}, "m", "Messages", al:openApp("Messages") },
  },
}
```

#### Modal Hotkeys - Sticky Mode

Use for sequences of related actions before manually exiting. Ideal for workflow-based operations:

```lua
-- filepath: .config/hammerspoon/init.lua
---@type Hotkeys.ModalSpec
local modeWindowManagerSticky = {
  trigger = { hk.mods.hyper, "space", "Window" },
  isOneShot = false,  -- or omit (false is default)
  specs = {
    { {}, "m", "Maximize", wm.maximize },
    { {}, "c", "Center", wm.center },
    { {}, "left", "Prev Screen", wm.screenPrev },
    { {}, "right", "Next Screen", wm.screenNext },
    { {}, "escape", nil, hk.activeModeExit },  -- Common exit key
  },
}

-- Bind modal hotkeys
hk:bindHotkeys({
  modes = { modeAppLauncherOneShot, modeWindowManagerSticky },
})
```

#### Custom Keyboard Layout Documentation

Document any dependencies on custom keyboard layouts:

```lua
-- filepath: .config/hammerspoon/init.lua
-- These hotkeys only make sense with my custom layout
-- https://github.com/minusfive/zmk-config
{ hk.mods.hyper, "7", "1/2 Left", wm:move(wm.layout.left50) },
```

### Window Management Patterns

#### Basic Window Movement

```lua
-- filepath: .config/hammerspoon/Spoons/WindowManager.spoon/init.lua
---Move window to a layout position
---@param unitRect hs.geometry.rect
---@return function
function WindowManager:move(unitRect)
  return function()
    local win = hs.window.focusedWindow()
    if win then
      win:move(unitRect, nil, true)
    end
  end
end
```

#### Window Focusing

```lua
-- filepath: .config/hammerspoon/Spoons/WindowManager.spoon/init.lua
---Focus window to the left
function WindowManager.focusL()
  local win = hs.window.focusedWindow()
  if win then
    win:focusWindowWest(nil, true, true)
  end
end
```

### Application Launching Patterns

#### Standard Launch and Focus

```lua
-- filepath: .config/hammerspoon/Spoons/AppLauncher.spoon/init.lua
---Open or focus an application
---@param appName string
---@return function
function AppLauncher:openApp(appName)
  return function()
    -- Check if app needs special handling
    if self:shouldFocusMostRecentWindow(appName) then
      -- Custom focus logic for apps like Microsoft Teams
      -- that create multiple windows
      local app = hs.application.find(appName)
      if app then
        local mainWindow = app:mainWindow()
        if mainWindow then
          mainWindow:focus()
        else
          app:activate()
        end
      else
        hs.application.launchOrFocus(appName)
      end
    else
      hs.application.launchOrFocus(appName)
    end
  end
end
```

Configure apps requiring special focus behavior in Spoon options:

```lua
-- filepath: .config/hammerspoon/Spoons/AppLauncher.spoon/init.lua
---@class AppLauncherOptions
options = {
  appNamesForFilters = {
    toFocusMostRecentWindow = { "Microsoft Teams" },
  },
}
```

### System Integration

#### Notifications

```lua
-- filepath: .config/hammerspoon/init.lua
---Send macOS system notification
---@param title string
---@param message? string
local function notify(title, message)
  local notification = hs.notify.new({
    title = title,
    subTitle = message or ""
  })
  if notification then
    notification:send()
  end
end

-- Usage in hotkeys
{
  {},
  "r",
  "Reload Config",
  function()
    notify("Reloading Configuration", "This may take a few seconds")
    hs.reload()
  end,
}
```

### Performance Considerations

- Use `hs.window.filter` for efficient window watching instead of polling
- Minimize animation duration for snappy window movements: `hs.window.animationDuration = 0`
- Lazy load Spoons only when needed
- Use watchers efficiently, clean up in `stop()` method
- Avoid blocking operations in hotkey callbacks

---

This configuration extends the main project guidelines with Hammerspoon-specific patterns for macOS automation and window management.
