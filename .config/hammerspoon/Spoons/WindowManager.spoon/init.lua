--- Module to manage / manipulate windows
---@class WindowManager
local WindowManager = {
  name = "WindowManager",
  version = "0.1",
  author = "http://github.com/minusfive",
  license = "MIT - https://opensource.org/licenses/MIT",

  ---@class WindowManagerOptions
  options = {
    enableFocusedWindowHighlight = false,
    appNamesForFilters = {
      toFocusMostRecentWindow = { "Microsoft Teams" },
      terminals = { "Terminal", "WezTerm", "Ghostty", "Kitty" },
      browsers = { "Safari", "Google Chrome", "Firefox", "Brave" },
    },
  },
}

-- Global settings
hs.window.animationDuration = 0.1
hs.window.highlight.ui.overlay = true
hs.window.highlight.ui.overlayColor = { hex = "#11111b", alpha = 0.000001 }
hs.window.highlight.ui.isolateColor = { hex = "#11111b", alpha = 0.9 }
hs.window.highlight.ui.frameWidth = 6
hs.window.highlight.ui.frameColor = { hex = "#cdd6f4", alpha = 0.2 }

---@alias hs.geometry.rect {x: number, y: number, w: number, h: number}

-- Convenience list of unit rects for common window layouts
---@enum (key) WindowManager.layout
WindowManager.layout = {
  maximized = { x = 0, y = 0, w = 1, h = 1 },

  --- 1/2
  top50 = { x = 0, y = 0, w = 1, h = 0.5 },
  bottom50 = { x = 0, y = 0.5, w = 1, h = 0.5 },
  left50 = { x = 0, y = 0, w = 0.5, h = 1 },
  center50 = { x = 0.25, y = 0, w = 0.5, h = 1 },
  right50 = { x = 0.5, y = 0, w = 0.5, h = 1 },

  --- 1/3
  left33 = { x = 0, y = 0, w = 0.3333, h = 1 },
  leftCenter33 = { x = 0.1666, y = 0, w = 0.3333, h = 1 }, --- Left of Center
  center33 = { x = 0.3333, y = 0, w = 0.3333, h = 1 },
  rightCenter33 = { x = 0.50, y = 0, w = 0.3333, h = 1 }, --- Right of Center
  right33 = { x = 0.6666, y = 0, w = 0.3333, h = 1 },

  --- 1/4
  first25 = { x = 0, y = 0, w = 0.25, h = 1 },
  second25 = { x = 0.25, y = 0, w = 0.25, h = 1 },
  third25 = { x = 0.50, y = 0, w = 0.25, h = 1 },
  fourth25 = { x = 0.75, y = 0, w = 0.25, h = 1 },

  topLeft25 = { x = 0, y = 0, w = 0.50, h = 0.50 },
  topRigh25 = { x = 0.50, y = 0, w = 0.50, h = 0.50 },
  bottomLeft25 = { x = 0, y = 0.50, w = 0.50, h = 0.50 },
  bottomRigh25 = { x = 0.50, y = 0.50, w = 0.50, h = 0.50 },
}

-- Wrapper to perform certain operations before and after window movement
-- to reduce artifacts
---@generic T
---@param fn function():`T`
---@return T
local function __optimizeFrame(fn)
  if not WindowManager.options.enableFocusedWindowHighlight then return fn() end

  hs.window.highlight.stop()
  local result = fn()
  hs.timer.doAfter(hs.window.animationDuration + 0.02, hs.window.highlight.start)
  return result
end

-- Move window to specified rect coordinates
---@param unit hs.geometry.rect
function WindowManager:move(unit)
  return function()
    __optimizeFrame(function() hs.window.focusedWindow():move(unit, nil, true) end)
  end
end

-- Toggle window "Full Screen" state
function WindowManager:toggleFullScreen()
  __optimizeFrame(function() hs.window.focusedWindow():toggleFullScreen() end)
end

-- Maximize window
function WindowManager:maximixe()
  __optimizeFrame(function() hs.window.focusedWindow():maximize() end)
end

-- Center window on screen
function WindowManager:center()
  __optimizeFrame(function() hs.window.focusedWindow():centerOnScreen(nil, true, 0) end)
end

-- Move window to next screen
function WindowManager:screenNext()
  __optimizeFrame(
    function() hs.window.focusedWindow():moveToScreen(hs.window.focusedWindow():screen():next(), false, true) end
  )
end

-- Move window to previous screen
function WindowManager:screenPrev()
  __optimizeFrame(
    function() hs.window.focusedWindow():moveToScreen(hs.window.focusedWindow():screen():previous(), false, true) end
  )
end

-- Places window in a specific location within current screen bounds
---@param window hs.window
---@param rect hs.geometry.rect
---@param duration? number
---@return hs.window
local function __setFrameInScreenBounds(window, rect, duration)
  __optimizeFrame(function() window:setFrameInScreenBounds(rect, duration) end)
  return window
end

-- Cycle window position to next available of equal size
---@param direction "<" | ">"
function WindowManager:cycleHorizontalPosition(direction)
  local screen = hs.window.focusedWindow():screen():frame()
  local window = hs.window.focusedWindow()
  local windowFrame = window:frame()
  local oldWindowFrame = windowFrame:copy()
  local neighbor = nil

  if direction == "<" then
    windowFrame.x = windowFrame.x >= windowFrame.w and windowFrame.x - windowFrame.w or screen.w - windowFrame.w
    neighbor = window:windowsToWest(nil, true, true)[1]
  elseif direction == ">" then
    windowFrame.x = windowFrame.x + windowFrame.w
    windowFrame.x = windowFrame.x <= (screen.w - windowFrame.w) and windowFrame.x or 0
    neighbor = window:windowsToEast(nil, true, true)[1]
  end

  -- Swap with neighbor
  if neighbor then __setFrameInScreenBounds(neighbor, oldWindowFrame) end
  __setFrameInScreenBounds(window, windowFrame)
end

-- Increase or decrease window width in steps
---@param direction "+" | "-"
---@param step? integer (Optional) number of pixes window should grow by. Defaults to 100.
---@param minWidth? integer (Optional) minimum window width. Max is always screen width.
function WindowManager:resizeWindowWidthInSteps(direction, step, minWidth)
  -- Defaults
  step = step or 100
  minWidth = minWidth or 200

  local screen = hs.window.focusedWindow():screen():frame()
  local window = hs.window.focusedWindow()
  local windowFrame = window:frame()
  local isCentered = math.abs(windowFrame.x - (screen.x2 - windowFrame.x2)) < 4

  if isCentered then step = step / 2 end

  if direction == "+" then
    windowFrame.w = windowFrame.w + step
    windowFrame.w = windowFrame.w > screen.w and screen.w or windowFrame.w
  elseif direction == "-" then
    windowFrame.w = windowFrame.w - step
    windowFrame.w = windowFrame.w < minWidth and minWidth or windowFrame.w
  end

  if windowFrame.x <= screen.x then
    windowFrame.x = screen.x
  elseif windowFrame.x2 >= screen.x2 then
    windowFrame.x = screen.w - windowFrame.w
  elseif isCentered then
    windowFrame.x = math.max(0, math.floor((screen.w - windowFrame.w) / 2))
  end

  __setFrameInScreenBounds(window, windowFrame)
end

-- Resize window height in steps
---@param direction "+" | "-"
---@param step? integer (Optional) number of pixes window should grow by. Defaults to 100.
---@param minHeight? integer (Optional) minimum window width. Max is always screen width.
function WindowManager:resizeWindowHeightInSteps(direction, step, minHeight)
  -- Defaults
  step = step or 100
  minHeight = minHeight or 200

  local screen = hs.window.focusedWindow():screen():frame()
  local window = hs.window.focusedWindow()
  local windowFrame = window:frame()
  local isCentered = math.abs(windowFrame.y - (screen.y2 - windowFrame.y2)) < (screen.y + 4)

  if direction == "+" then
    windowFrame.h = windowFrame.h + step
    windowFrame.h = windowFrame.h > screen.h and screen.h or windowFrame.h
  elseif direction == "-" then
    windowFrame.h = windowFrame.h - step
    windowFrame.h = windowFrame.h < minHeight and minHeight or windowFrame.h
  end

  if windowFrame.y <= screen.y then
    windowFrame.y = screen.y
  elseif windowFrame.y2 >= screen.y2 then
    windowFrame.y = screen.h - windowFrame.h
  elseif isCentered then
    windowFrame.y = math.max(0, math.floor((screen.h - windowFrame.h) / 2))
  end

  __setFrameInScreenBounds(window, windowFrame)
end

-- Focus window to the left
function WindowManager:focusL() hs.window.focusedWindow():focusWindowWest(nil, true, true) end

-- Focus window to the right
function WindowManager:focusR() hs.window.focusedWindow():focusWindowEast(nil, true, true) end

-- Cycle window position to the right
function WindowManager:moveR() return WindowManager:cycleHorizontalPosition(">") end

-- Cycle window position to the left
function WindowManager:moveL() return WindowManager:cycleHorizontalPosition("<") end

-- Shrink window horizontally
function WindowManager:shrinkX() return WindowManager:resizeWindowWidthInSteps("-") end

-- Grow window horizontally
function WindowManager:growX() return WindowManager:resizeWindowWidthInSteps("+") end

-- Shrink window vertically
function WindowManager:shrinkY() return WindowManager:resizeWindowHeightInSteps("-") end

-- Grow window vertically
function WindowManager:growY() return WindowManager:resizeWindowHeightInSteps("+") end

-- Position mouse in center of focused windows whenever focus changes
---@param window hs.window
local function mouseFollowsFocus(window)
  -- Only update mouse if mouse buttons are not pressed (e.g. focus wasn't changed by mouse)
  if #hs.mouse.getButtons() ~= 0 then return end

  -- Position mouse in center of focused window if it's not already within its frame
  local currentMousePosition = hs.geometry(hs.mouse.absolutePosition())
  local frame = window:frame()
  if not currentMousePosition:inside(frame) then hs.mouse.absolutePosition(frame.center) end
end

---@type string | nil
local lastAppFocused = nil

---Restores focus to most recently created window of specific apps on activation
---@param window hs.window
---@param appName string
local function focusMostRecentAppWindow(window, appName)
  if appName == lastAppFocused then return end
  lastAppFocused = appName

  -- Only focus most recent window for specific apps
  if not hs.fnutils.contains(WindowManager.options.appNamesForFilters.toFocusMostRecentWindow, appName) then return end

  ---@type hs.application | nil
  local app = window:application()
  if not app then return end

  ---@type hs.window[] | nil
  local appWindows = app:visibleWindows()
  if not appWindows or #appWindows == 0 then return end

  ---@type number[] | nil
  local appWinIds = hs.fnutils.imap(appWindows, function(win) return win:id() end)
  if not appWinIds or #appWinIds == 0 then return end

  local maxWinId = math.max(table.unpack(appWinIds))

  ---@type hs.window | nil
  local mostRecentWin = hs.fnutils.find(appWindows, function(win) return win:id() == maxWinId end)
  if not mostRecentWin then return end

  mostRecentWin:becomeMain():focus()
end

-- Watch for focused window changes and trigger some actions
---@param window hs.window
---@param appName string
local function focusedWindowWatcher(window, appName)
  mouseFollowsFocus(window)
  focusMostRecentAppWindow(window, appName)
end

-- Ensure all terminal windows open on specific positions depending on screen size
---@param window hs.window
local function terminalNewWindowWatcher(window)
  local desiredPosition = WindowManager.layout.right50
  if window:screen():fullFrame().w >= 5120 then desiredPosition = WindowManager.layout.center33 end
  window:moveToUnit(desiredPosition, 0)
end

-- Ensure all browser windows open on specific positions depending on screen size
---@param window hs.window
local function browserNewWindowWatcher(window)
  ---@type hs.application | nil
  local app = window:application()
  app = app and app:name()

  local pos = { default = WindowManager.layout.right50, above5125 = WindowManager.layout.right33 }

  if app == "Safari" then pos = { default = WindowManager.layout.left50, above5125 = WindowManager.layout.left33 } end

  window:moveToUnit((window:screen():fullFrame().w >= 5120) and pos.above5125 or pos.default, 0)
end

--- Initialize WindowManager
function WindowManager:init()
  local focusedWindowFilter = hs.window.filter.new():setOverrideFilter({
    visible = true,
    focused = true,
    activeApplication = true,
    allowRoles = "AXStandardWindow",
  })

  local terminalWindowFilter = hs.window.filter
    .new(WindowManager.options.appNamesForFilters.terminals)
    :setOverrideFilter({ visible = true, allowRoles = "AXStandardWindow" })

  local browserWindowFilter = hs.window.filter
    .new(WindowManager.options.appNamesForFilters.browsers)
    :setOverrideFilter({ visible = true, allowRoles = "AXStandardWindow" })

  --- Starts the WindowManager watchers
  function WindowManager:start()
    focusedWindowFilter:subscribe(hs.window.filter.windowFocused, focusedWindowWatcher)
    terminalWindowFilter:subscribe(hs.window.filter.windowCreated, terminalNewWindowWatcher)
    browserWindowFilter:subscribe(hs.window.filter.windowCreated, browserNewWindowWatcher)

    if WindowManager.options.enableFocusedWindowHighlight then hs.window.highlight.start() end
  end

  --- Stops the WindowManager watchers
  function WindowManager:stop()
    focusedWindowFilter:unsubscribe(hs.window.filter.windowFocused, focusedWindowWatcher)
    terminalWindowFilter:unsubscribe(hs.window.filter.windowCreated, terminalNewWindowWatcher)
    browserWindowFilter:unsubscribe(hs.window.filter.windowCreated, browserNewWindowWatcher)

    hs.window.highlight.stop()
  end
end

return WindowManager
