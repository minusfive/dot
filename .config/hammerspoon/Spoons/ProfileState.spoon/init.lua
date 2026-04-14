---@class ProfileState
---@field options {stateFileRelPath:string, defaultProfile:"work"|"personal"}
local ProfileState = {
  name = "ProfileState",
  version = "0.1",
  author = "http://github.com/minusfive",
  license = "MIT - https://opensource.org/licenses/MIT",
  options = {
    stateFileRelPath = "/minusfive/profile",
    defaultProfile = "work",
  },
}

---@return string
local function __stateHome()
  local stateHome = os.getenv("XDG_STATE_HOME")
  if stateHome and #stateHome > 0 then return stateHome end

  local home = os.getenv("HOME") or ""
  return home .. "/.local/state"
end

---@return string
local function __stateFilePath() return __stateHome() .. ProfileState.options.stateFileRelPath end

---@param profile string
---@return boolean
function ProfileState:isValid(profile) return profile == "work" or profile == "personal" end

---@return "work"|"personal"
function ProfileState:read()
  local file = io.open(__stateFilePath(), "r")
  if not file then return ProfileState.options.defaultProfile end

  local profile = file:read("*l") or ""
  file:close()

  if ProfileState:isValid(profile) then return profile end
  return ProfileState.options.defaultProfile
end

---@param profile? string
---@return boolean
function ProfileState:isWorkProfile(profile)
  local resolvedProfile = profile or self:read()
  return resolvedProfile == "work"
end

---@param profile? string
---@return boolean
function ProfileState:isPersonalProfile(profile)
  local resolvedProfile = profile or self:read()
  return resolvedProfile == "personal"
end

---@param profile? string
---@return "work"|"personal"
function ProfileState:syncSettings(profile)
  local resolvedProfile = profile or self:read()
  hs.settings.set("hs.minusfive.profile", resolvedProfile)
  hs.settings.set("hs.minusfive.profile.is_work", self:isWorkProfile(resolvedProfile))
  hs.settings.set("hs.minusfive.profile.is_personal", self:isPersonalProfile(resolvedProfile))
  return resolvedProfile
end

function ProfileState:init() return self end

function ProfileState:start() return self end

function ProfileState:stop() return self end

---@param _mapping table<string, hs.hotkey.ModalKey>
function ProfileState:bindHotkeys(_mapping) return self end

return ProfileState
