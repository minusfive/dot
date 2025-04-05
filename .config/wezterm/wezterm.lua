---Returns the parent directory of a path.
---@param path string
local function parent_dir(path) return path:match("(.*)/") end

-- Pull in the wezterm API
local wezterm = require("wezterm")
local catppuccin = wezterm.plugin.require("https://github.com/minusfive/catppuccin-wezterm")

local act = wezterm.action

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then config = wezterm.config_builder() end

-- This is where you actually apply your config choices
-- Performance
config.front_end = "WebGpu"
config.animation_fps = 60

local contents_dir = parent_dir(wezterm.executable_dir)
local resources_dir = contents_dir .. "/Resources"

-- Enable advanced features
config.set_environment_variables = {
  TERMINFO_DIRS = resources_dir .. "/terminfo",
  WSLENV = "TERMINFO_DIRS",
}
config.term = "wezterm"

-- Default working directory
config.default_cwd = wezterm.home_dir .. "/dev"

-- Get theme for customization
local ctp = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]

-- Tab bar
config.use_fancy_tab_bar = false -- Use retro tab bar
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32
ctp.tab_bar.active_tab.intensity = "Bold"
ctp.tab_bar.inactive_tab.bg_color = catppuccin.colors.mocha.crust
ctp.tab_bar.inactive_tab.fg_color = catppuccin.colors.mocha.overlay2
ctp.tab_bar.inactive_tab.intensity = "Half"
ctp.tab_bar.inactive_tab_hover.fg_color = ctp.tab_bar.inactive_tab.fg_color
ctp.tab_bar.inactive_tab_hover.intensity = "Normal"
wezterm.on("format-tab-title", function(tab)
  local title = tab.tab_title

  if (not title) or #title <= 0 then title = tab.active_pane.title end

  return {
    { Text = "  " .. (tab.tab_index + 1) .. "- " .. title .. " " },
    { Foreground = { Color = catppuccin.colors.mocha.base } },
    { Text = "🮇" },
  }
end)

-- Command and character selection palettes
config.command_palette_bg_color = catppuccin.colors.mocha.surface0
config.command_palette_fg_color = catppuccin.colors.mocha.lavender
config.command_palette_font_size = 18
config.char_select_bg_color = catppuccin.colors.mocha.surface0
config.char_select_fg_color = catppuccin.colors.mocha.lavender
config.char_select_font_size = 18

-- Windows
config.window_decorations = "RESIZE"
config.window_padding = {
  bottom = 0,
  left = 0,
  right = 0,
  top = 0,
}

-- Panes
config.inactive_pane_hsb = {
  brightness = 0.7,
  saturation = 0.9,
}

-- Use Colemak-DH for quick select, prioritizing inward rolls
config.launcher_alphabet = "arstgqwfpbzxcdvoienmyuljhkARSTGQWFPBZXCDVOIENMYULJHK1234567890"
config.quick_select_alphabet = config.launcher_alphabet

-- Cursor
config.cursor_blink_rate = 333
config.default_cursor_style = "BlinkingBlock"

-- Fonts & Typography
config.font = wezterm.font({
  family = "JetBrains Mono",
  harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
})
config.font_size = 18.0
config.line_height = 1.25
config.adjust_window_size_when_changing_font_size = false
config.custom_block_glyphs = true
config.anti_alias_custom_block_glyphs = true
config.bold_brightens_ansi_colors = true
config.underline_position = -8

-- Keys
config.use_ime = false -- Send keycodes as they are
config.enable_kitty_keyboard = true
config.enable_csi_u_key_encoding = false

-- Set customized theme
config.color_schemes = { ["Catppuccin Mocha (minusfive)"] = ctp }
config.color_scheme = "Catppuccin Mocha (minusfive)"

-- Show active workspace in the status area
-- wezterm.on("update-right-status", function(window, pane)
-- 	window:set_right_status(window:active_workspace())
-- end)

-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window)
  local name = window:active_key_table()
  if name then name = "TABLE: " .. name end
  window:set_right_status(name or "")
end)

-- Key mappings
config.leader = {
  key = "Space",
  mods = "OPT",
}

---Direction string differs between actions / methods. This map bridges the gap.
local directionMap = {
  Down = "Bottom",
  Left = "Left",
  Right = "Right",
  Up = "Top",
}

---@class DirectionalKeybinding
---@field direction "Up" | "Down" | "Left" | "Right"
---@field key? string
---@field mods? string

---Tries to activate a pane in the given direction, or splits the current pane in that direction.
---@param opts DirectionalKeybinding
local function activateOrSplitPane(opts)
  return {
    key = opts.key or (opts.direction .. "Arrow"),
    mods = opts.mods,
    action = wezterm.action_callback(function(_, pane)
      local pane_at_direction = pane:tab():get_pane_direction(opts.direction)

      if pane_at_direction then
        pane_at_direction:activate()
        return
      end

      pane:split({ direction = directionMap[opts.direction] })
    end),
  }
end

---Resizes pane in the given direction.
---@param opts DirectionalKeybinding
local function resizePane(opts)
  return {
    key = opts.key or (opts.direction .. "Arrow"),
    mods = opts.mods,
    action = act.AdjustPaneSize({ opts.direction, 2 }),
  }
end

config.keys = {
  activateOrSplitPane({ mods = "CMD", direction = "Right" }),
  activateOrSplitPane({ mods = "CMD", direction = "Left" }),
  activateOrSplitPane({ mods = "CMD", direction = "Down" }),
  activateOrSplitPane({ mods = "CMD", direction = "Up" }),

  resizePane({ mods = "SHIFT", direction = "Right" }),
  resizePane({ mods = "SHIFT", direction = "Left" }),
  resizePane({ mods = "SHIFT", direction = "Down" }),
  resizePane({ mods = "SHIFT", direction = "Up" }),

  { mods = "LEADER", key = "c", action = act.ActivateCopyMode },
  { mods = "LEADER", key = "s", action = act.QuickSelect },

  { mods = "OPT", key = "s", action = act.PaneSelect },
  { mods = "OPT|SHIFT", key = "s", action = act.PaneSelect({ mode = "SwapWithActive" }) },

  { mods = "CMD", key = "z", action = act.TogglePaneZoomState },

  { mods = "CMD", key = "p", action = act.ActivateCommandPalette },

  { mods = "CMD|OPT", key = "t", action = act.ShowTabNavigator },

  { mods = "CMD", key = "w", action = act.CloseCurrentPane({ confirm = true }) },
  { mods = "CMD|SHIFT", key = "w", action = act.CloseCurrentTab({ confirm = true }) },

  { mods = "CMD", key = "l", action = act.ShowLauncherArgs({ flags = "LAUNCH_MENU_ITEMS|TABS|WORKSPACES" }) },
}

-- folke/zen-mode.nvim
wezterm.on("user-var-changed", function(window, pane, name, value)
  local overrides = window:get_config_overrides() or {}
  if name == "ZEN_MODE" then
    local incremental = value:find("+")
    local number_value = tonumber(value)
    if incremental ~= nil then
      while number_value > 0 do
        window:perform_action(wezterm.action.IncreaseFontSize, pane)
        number_value = number_value - 1
      end
      overrides.enable_tab_bar = false
    elseif number_value < 0 then
      window:perform_action(wezterm.action.ResetFontSize, pane)
      overrides.font_size = nil
      overrides.enable_tab_bar = true
    else
      overrides.font_size = number_value
      overrides.enable_tab_bar = false
    end
  end
  window:set_config_overrides(overrides)
end)

-- and finally, return the configuration to wezterm
return config
