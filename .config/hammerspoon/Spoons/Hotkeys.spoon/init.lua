-- Module to handle hotkey actions

---@alias hs.hotkey.KeySpec [string[], string, string, function?, function?, function?]

---@class Hotkeys.ActiveMode
---@field modal? hs.hotkey.modal
---@field specs? hs.hotkey.KeySpec[]
---@field triggerSpec? hs.hotkey.KeySpec
---@field isOneShot? boolean

---@class Hotkeys.ModalSpec
---@field trigger hs.hotkey.KeySpec
---@field specs hs.hotkey.KeySpec[]
---@field isOneShot? boolean

---@class Hotkeys
---@field activeMode? Hotkeys.ActiveMode
---@field keyListener? hs.eventtap
---@field menuBarItem? hs.menubar
local Hotkeys = {
  name = "Hotkeys",
  version = "0.1",
  author = "http://github.com/minusfive",
  license = "MIT - https://opensource.org/licenses/MIT",
  activeMode = nil,
  keyListener = nil,
  menuBarItem = nil,
}

-- Modifier keys
Hotkeys.mods = {
  alt = { "alt" },
  cmd = { "cmd" },
  ctrl = { "ctrl" },
  hyper = { "ctrl", "alt", "shift", "cmd" },
  meh = { "ctrl", "alt", "shift" },
  shift = { "shift" },
}

-- Setup modal hotkeys environments
---@param modalSpec Hotkeys.ModalSpec
---@return nil
local function configureModal(modalSpec)
  if not modalSpec.specs or not #modalSpec.specs then return end

  local modal = hs.hotkey.modal.new(table.unpack(modalSpec.trigger))
  local specs = modalSpec.specs

  -- Bind all specs
  for _, spec in ipairs(specs) do
    modal:bind(table.unpack(spec))
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  function modal:entered()
    Hotkeys.activeMode = {
      modal = modal,
      specs = specs,
      triggerSpec = modalSpec.trigger,
      isOneShot = modalSpec.isOneShot,
    }

    if Hotkeys.keyListener then Hotkeys.keyListener:start() end

    if Hotkeys.menuBarItem then
      Hotkeys.menuBarItem:returnToMenuBar()
      Hotkeys.menuBarItem:setTitle(hs.styledtext(modalSpec.trigger[3]:upper(), {
        font = { size = 12 },
      }))
    end

    hs.notify.new({ title = modalSpec.trigger[3], subTitle = "Hokeys Mode" }):send()
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  function modal:exited()
    Hotkeys.activeMode = nil

    if Hotkeys.keyListener then Hotkeys.keyListener:stop() end

    if Hotkeys.menuBarItem then Hotkeys.menuBarItem:removeFromMenuBar() end

    hs.notify.new({ title = "Normal", subTitle = "Hotkeys Mode" }):send()
  end
end

-- EventTap handler which blocks any key events not found in a mode's specs
---@param event hs.eventtap.event
local function keyListenerFn(event)
  -- Noop if no active mode specs found
  if not Hotkeys.activeMode or not Hotkeys.activeMode.specs or not #Hotkeys.activeMode.specs then return false end

  local eventMods = event:getFlags()
  local eventKey = hs.keycodes.map[event:getKeyCode()]
  eventKey = type(eventKey) == "string" and string.lower(eventKey)

  -- Allow key event if it's found in active mode hotkeys specs
  for _, spec in ipairs(Hotkeys.activeMode.specs) do
    if eventKey == string.lower(spec[2]) and type(eventMods) == "table" and eventMods:containExactly(spec[1]) then
      -- If it's a one-shot mode, execute the action and exit
      if Hotkeys.activeMode.isOneShot then
        Hotkeys.activeMode.modal:exit()
        if type(spec[4]) == "function" then spec[4]() end
        -- Block the event so it doesn't propagate to the application
        return true
      end
      -- otherwise just rely on modal handling
      return
    end
  end

  -- Otherwise block it
  return true
end

-- Allows exiting the currently active modal state
function Hotkeys:activeModeExit()
  if Hotkeys.activeMode then Hotkeys.activeMode.modal:exit() end
end

---@class Hotkeys.Config
---@field modes? Hotkeys.ModalSpec[]
---@field specs? hs.hotkey.KeySpec[]

-- Bind hotkeys
---@param config Hotkeys.Config
function Hotkeys:bindHotkeys(config)
  -- Root hotkeys
  if config.specs then
    for _, spec in ipairs(config.specs) do
      hs.hotkey.bind(table.unpack(spec))
    end
  end

  -- Modal hotkeys
  if config.modes then
    if not self.menuBarItem then self.menuBarItem = hs.menubar.new(false, "hs.minusfive.hotkeys.mode") end

    if not self.keyListener then
      self.keyListener = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, keyListenerFn)
    end

    for _, mode in ipairs(config.modes) do
      configureModal(mode)
    end
  end
end

return Hotkeys
