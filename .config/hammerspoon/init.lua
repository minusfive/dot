-- Load type annotations and docs for LSP
hs.loadSpoon("EmmyLua")
hs.loadSpoon("WindowManager")
hs.loadSpoon("AppLauncher")
hs.loadSpoon("Caffeine")
hs.loadSpoon("Hotkeys")

---@type AppLauncher
local al = spoon.AppLauncher

---@type WindowManager
local wm = spoon.WindowManager

---@type Caffeine
local cf = spoon.Caffeine

---@type Hotkeys
local hk = spoon.Hotkeys

-- Set default settings
hs.hotkey.alertDuration = 0.3
hs.alert.defaultStyle = {
  strokeWidth = 0,
  strokeColor = { white = 0, alpha = 0 },
  fillColor = { white = 0.05, alpha = 0.8 },
  textColor = { white = 1, alpha = 1 },
  textFont = ".AppleSystemUIFont",
  textStyle = { paragraphStyle = { lineSpacing = 10 } },
  textSize = 18,
  radius = 6,
  atScreenEdge = 1,
  fadeInDuration = 0.05,
  fadeOutDuration = 0.05,
  padding = 18,
}

-- Hotkeys
-- Hotkeys shared by all modals
---@type hs.hotkey.KeySpec[]
local commonModalSpecs = {
  -- Uniform ways of exiting modal environments
  { {}, "escape", nil, hk.activeModeExit },
}

-- The most used shortcuts, available through a single combination, not modal
---@type hs.hotkey.KeySpec[]
local normalSpecs = {
  -- Apps
  -- meh + a: AppLauncher mode (one shot)
  -- hyper + a: AppLauncher mode (sticky)
  { hk.mods.meh, "e", "Microsoft Outlook", al:openApp("Microsoft Outlook") }, -- email
  { hk.mods.meh, "f", "Finder", al:openApp("Finder") },
  { hk.mods.meh, "g", "Google Chrome", al:openApp("Google Chrome") },
  { hk.mods.meh, "h", "Hammerspoon", al:openApp("Hammerspoon") },
  { hk.mods.meh, "i", "Insomnium", al:openApp("Insomnium") },
  { hk.mods.meh, "n", "Notes", al:openApp("Notes") },
  { hk.mods.meh, "o", "Obsidian", al:openApp("Obsidian") },
  { hk.mods.meh, "p", "1Password", al:openApp("1Password") },
  { hk.mods.meh, "r", "Reminders", al:openApp("Reminders") },
  { hk.mods.meh, "s", "Safari", al:openApp("Safari") },
  { hk.mods.meh, "c", "Slack", al:openApp("Slack") }, -- chat
  { hk.mods.meh, "t", "WezTerm", al:openApp("WezTerm") },
  { hk.mods.meh, "v", "Microsoft Teams", al:openApp("Microsoft Teams") },
  { hk.mods.meh, "x", "Microsoft Excel", al:openApp("Microsoft Excel") },
  { hk.mods.meh, "z", "Zoom.us", al:openApp("Zoom.us") },

  -- These only make sense with my custom layout https://github.com/minusfive/zmk-config
  { hk.mods.hyper, "7", "1/2 Left", wm:move(wm.layout.left50) },
  { hk.mods.hyper, "8", "1/2 Center", wm:move(wm.layout.center50) },
  { hk.mods.hyper, "9", "1/2 Right", wm:move(wm.layout.right50) },

  { hk.mods.meh, "5", "1/2 Top", wm:move(wm.layout.top50) },
  { hk.mods.meh, "0", "1/2 Bottom", wm:move(wm.layout.bottom50) },

  { hk.mods.meh, "7", "1/3 Left", wm:move(wm.layout.left33) },
  { hk.mods.meh, "8", "1/3 Center", wm:move(wm.layout.center33) },
  { hk.mods.meh, "9", "1/3 Right", wm:move(wm.layout.right33) },

  { hk.mods.meh, "1", "1/4 1", wm:move(wm.layout.first25) },
  { hk.mods.meh, "2", "1/4 2", wm:move(wm.layout.second25) },
  { hk.mods.meh, "3", "1/4 3", wm:move(wm.layout.third25) },
  { hk.mods.meh, "4", "1/4 4", wm:move(wm.layout.fourth25) },

  -- Corners
  { hk.mods.hyper, "1", "1/4 Top-Left", wm:move(wm.layout.topLeft25) },
  { hk.mods.hyper, "5", "1/4 Top-Right", wm:move(wm.layout.topRigh25) },
  { hk.mods.hyper, "6", "1/4 Bottom-Left", wm:move(wm.layout.bottomLeft25) },
  { hk.mods.hyper, "0", "1/4 Bottom-Right", wm:move(wm.layout.bottomRigh25) },

  -- Focus
  { hk.mods.meh, "[", "Focus Window Left", wm.focusL },
  { hk.mods.meh, "]", "Focus Window Right", wm.focusR },

  -- Move
  { hk.mods.hyper, "[", "Move Left", wm.moveL },
  { hk.mods.hyper, "]", "Move Right", wm.moveR },

  -- Resize
  { hk.mods.meh, "=", "Grow Width", wm.growX },
  { hk.mods.meh, "-", "Shrink Width", wm.shrinkX },
  { hk.mods.hyper, "=", "Grow Height", wm.growY },
  { hk.mods.hyper, "-", "Shrink Height", wm.shrinkY },
}

-- Modal hotkeys
-- AppLauncher mode
---@type hs.hotkey.KeySpec[]
local appLauncherSpecs = {
  { {}, "d", "Discord", al:openApp("Discord") },
  { {}, "m", "Messages", al:openApp("Messages") },
  { {}, "w", "WhatsApp", al:openApp("WhatsApp") },
}

---@type Hotkeys.ModalSpec
local modeAppLauncherOneShot = {
  trigger = { hk.mods.meh, "a", "App Launcher" },
  isOneShot = true,
  specs = appLauncherSpecs,
}

---@type Hotkeys.ModalSpec
local modeAppLauncherSticky = {
  trigger = { hk.mods.hyper, "a", "App Launcher" },
  specs = appLauncherSpecs,
}

-- Window manager mode
---@type hs.hotkey.KeySpec[]
local windowModeSpecs = {
  -- Resize
  { {}, "m", "Maximize", wm.maximixe },
  { {}, "f", "Full Screen", wm.toggleFullScreen },
  { {}, "c", "Center", wm.center },

  -- Move
  { {}, "left", "Prev Screen", wm.screenPrev },
  { {}, "right", "Next Screen", wm.screenNext },
}

---@type Hotkeys.ModalSpec
local modeWindowManagerOneShot = {
  trigger = { hk.mods.meh, "space", "Window" },
  isOneShot = true,
  specs = windowModeSpecs,
}

---@type Hotkeys.ModalSpec
local modeWindowManagerSticky = {
  trigger = { hk.mods.hyper, "space", "Window" },
  specs = windowModeSpecs,
}

-- System manipulation mode
---@type Hotkeys.ModalSpec
local modeSystem = {
  trigger = { hk.mods.meh, ",", "System" }, -- `cmd + ,` is the standard shortcut for preferences on macOS
  isOneShot = true,
  specs = {
    { {}, "a", "Activity Monitor", al:openApp("Activity Monitor") },
    { {}, "c", "Caffeine", cf.toggle },
    { {}, "h", "Hammerspoon", al:openApp("Hammerspoon") },
    {
      {},
      "r",
      "Reload Config",
      function()
        hs.notify.new({ title = "Reloading Configuration", subTitle = "This may take a few seconds" }):send()
        hs.reload()
      end,
    },
    { {}, ",", "System Preferences", al:openApp("System Preferences") },
  },
}

-- Append commonModalSpecs to each modal's specs
hs.fnutils.each(
  { modeAppLauncherOneShot, modeAppLauncherSticky, modeSystem, modeWindowManagerOneShot, modeWindowManagerSticky },
  function(modalSpec) modalSpec.specs = hs.fnutils.concat(modalSpec.specs, commonModalSpecs) end
)

hk:bindHotkeys({
  specs = normalSpecs,
  modes = {
    modeAppLauncherOneShot,
    modeAppLauncherSticky,
    modeSystem,
    modeWindowManagerOneShot,
    modeWindowManagerSticky,
  },
})

-- Start caffeine
cf.options.notifyOnStateChange = true
cf:start()

--- Start WindowManager
wm:start() -- too slow

--- Start AppLauncher
al:start()

-- Enable HS CLI (inter-process communication)
require("hs.ipc")

-- Notify on config [re]load
hs.notify.new({ title = "Configuration Loaded", subTitle = "Settings applied" }):send()
