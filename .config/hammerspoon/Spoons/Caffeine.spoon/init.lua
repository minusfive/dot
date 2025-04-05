-- Module for preventing system sleep

---@class Caffeine Allows preventing system sleep
---@field menuBarItem? hs.menubar
---@field watcher? hs.caffeinate.watcher
local Caffeine = {
  name = "Caffeine",
  version = "0.1",
  author = "http://github.com/minusfive",
  license = "MIT - https://opensource.org/licenses/MIT",

  ---@class CaffeineOptions
  ---@field notifyOnStateChange? boolean
  options = {
    notifyOnStateChange = false,
  },
}

-- Constants
local __sleepType = "displayIdle"
local __stateKey = "caffeine"

-- Gets the menuIcon from state
---@param isActive? boolean
local function __getMenuIcon(isActive) return isActive and "0.0" or "-.-" end

--- Gets the tooltip from state
---@param isActive? boolean
local function __getMenuTooltip(isActive) return isActive and "Caffeinated" or "Sleepy" end

-- Sends a system notification whenever an app is activated
---@param isActive? boolean
local function __sendAppActivationNotification(isActive)
  if not Caffeine.options.notifyOnStateChange then return end

  local notification = hs.notify.new(nil, {
    title = __getMenuIcon(isActive),
    subTitle = __getMenuTooltip(isActive),
  })

  if notification then notification:send() end
end

-- Persists state in OS defaults table
---@param isActive? boolean
local function __persistState(isActive) hs.settings.set(__stateKey, isActive) end

-- Reads state from OS defaults table
local function __readPersistedState() return hs.settings.get(__stateKey) end

-- Toggle menuBarItem
---@param isActive? boolean
local function __toggleMenuBarItem(isActive)
  Caffeine.menuBarItem:setTitle(__getMenuIcon(isActive))
  Caffeine.menuBarItem:setTooltip(__getMenuTooltip(isActive))
end

-- Toggles system caffeination
---@param shouldActivate? boolean | table
function Caffeine.toggle(shouldActivate)
  ---@type boolean | nil
  if type(shouldActivate) == "boolean" then
    hs.caffeinate.set(__sleepType, shouldActivate)
  else
    hs.caffeinate.toggle(__sleepType)
  end

  ---@type boolean | nil
  local isActive = hs.caffeinate.get(__sleepType)

  __persistState(isActive)
  __toggleMenuBarItem(isActive)
  __sendAppActivationNotification(isActive)
end

function Caffeine:start()
  if not Caffeine.menuBarItem then
    Caffeine.menuBarItem = hs.menubar.new(true, "hs.minusfive.caffeine")
    Caffeine.menuBarItem:setClickCallback(Caffeine.toggle)
  end
  Caffeine.toggle(__readPersistedState() or false)
end

function Caffeine:stop()
  if Caffeine.menuBarItem then Caffeine.menuBarItem:delete() end
end

return Caffeine
