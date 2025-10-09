local Logos = require("config.logos")

-- Borders
local border = {
  topPad = { "", " ", "", "", "", "", "", "" },
}

-- Window options
local wo = {
  snacks = {
    picker = {
      list = {
        statuscolumn = "%#SnacksPickerListItemSign#%{v:relnum?'▎':''}%#SnacksPickerListItemSignCursorLine#%{v:relnum?'':'▎'}",
        number = true,
        numberwidth = 1,
        relativenumber = true,
      },
      preview = {
        foldcolumn = "0",
        number = true,
        relativenumber = false,
        signcolumn = "no",
      },
    },
  },
}

local function responsiveLayout() return vim.o.columns >= 120 and "lg" or "sm" end

--- Show which-key help for local window keymaps
local function showWhichKeyLocal()
  if package.loaded["which-key"] then require("which-key").show({ global = false }) end
end

--- Keymaps shared by all picker windows
local pickerWinCommonKeymaps = {
  -- these interfere with which-key scrolling
  ["<c-d>"] = false,
  ["<c-u>"] = false,

  -- use which-key for help
  ["<c-/>"] = { showWhichKeyLocal, desc = "Help", mode = { "n", "i", "v" } },
  ["?"] = { showWhichKeyLocal, desc = "Help", mode = { "n", "v" } },

  -- scroll with PageUp/Down
  ["<PageDown>"] = { "preview_scroll_down", desc = "Preview Scroll Down", mode = { "n", "i", "v" } },
  ["<PageUp>"] = { "preview_scroll_up", desc = "Preview Scroll Up", mode = { "n", "i", "v" } },
  ["<A-PageDown>"] = { "list_scroll_down", desc = "List Scroll Down", mode = { "n", "i", "v" } },
  ["<A-PageUp>"] = { "list_scroll_up", desc = "List Scroll Up", mode = { "n", "i", "v" } },
}

--- Keymaps for input picker
local pickerInputKeymaps = vim.deepcopy(pickerWinCommonKeymaps)
pickerInputKeymaps["<a-Up>"] = { "history_back", desc = "History Back", mode = { "n", "i", "v" } }
pickerInputKeymaps["<a-Down>"] = { "history_forward", desc = "History Forward", mode = { "n", "i", "v" } }

---Increase or reset terminal font size. Only supports WezTerm (for now).
---Requires tmux setting or no effect: set-option -g allow-passthrough on
---@param shouldIncreaseFontSize boolean
local function toggleFontSize(shouldIncreaseFontSize)
  if vim.env.TERM_PROGRAM ~= "WezTerm" then
    vim.notify("Font size manipulation only supported on WezTerm", vim.log.levels.WARN, { title = "Snacks" })
    return
  end
  local fontSize = shouldIncreaseFontSize and "+4" or "RESET"
  ---@diagnostic disable-next-line: undefined-field
  local stdout = vim.loop.new_tty(1, false)
  stdout:write(
    ("\x1bPtmux;\x1b\x1b]1337;SetUserVar=%s=%s\b\x1b\\"):format(
      "WEZTERM_CHANGE_FONT_SIZE",
      vim.fn.system({ "base64" }, fontSize)
    )
  )
  vim.cmd([[redraw]])
end

---Update the picker preview title for file items to include the file path.
---@param ctx snacks.picker.preview.ctx
local function update_picker_preview_file_title(ctx)
  local res = Snacks.picker.preview.file(ctx)
  if ctx.item.file then
    local path = Snacks.picker.util.path(ctx.item) or ctx.item.file
    path = Snacks.picker.util.truncpath(path, 80, { cwd = ctx.picker:cwd() })
    -- WARN: `picker.preview:set_title(item.file)` doesn't work
    ctx.picker.preview:set_title(path)
  end
  return res
end

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    optional = true,
    -- dev = true,

    ---@type snacks.Config|{}
    opts = {
      -- Animation
      animate = {
        easing = "inQuad",
        duration = { total = 100 },
      },

      -- Dashboard
      dashboard = {
        width = 50,

        preset = { header = Logos.v2 },

        sections = {
          { section = "header", padding = { 0, 0 } },
          { key = "l", hidden = true, desc = "Lazy", action = ":Lazy" },
          { key = "q", hidden = true, desc = "Quit", action = ":qa" },
          { key = "s", hidden = true, desc = "Session Restore", section = "session" },

          --- Neovim Version
          function()
            return {
              align = "center",
              padding = { 1, 0 },
              text = {
                { "Neovim ", hl = "footer" },
                { tostring(vim.version()), hl = "special" },
              },
            }
          end,

          --- Stats
          function()
            local stats = Snacks.dashboard.lazy_stats
            stats = stats and stats.startuptime > 0 and stats or require("lazy.stats").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

            return {
              align = "center",
              padding = { 0, 0 },
              text = {
                { tostring(stats.loaded), hl = "special" },
                { " / ", hl = "footer" },
                { tostring(stats.count), hl = "special" },
                { " plugins loaded in ", hl = "footer" },
                { ms .. "ms", hl = "special" },
              },
            }
          end,
        },
      },

      -- Image Rendering
      -- image = {
      --   resolve = function(path, src)
      --     if LazyVim.is_loaded("obsidian.nvim") and require("obsidian"):get_client():path_is_note(path) then
      --       return require("obsidian.path").resolve(self, opts?) (src)
      --     end
      --   end,
      -- },

      -- Indentation guides
      indent = {
        chunk = {
          enabled = true,
          only_current = true,
        },
        indent = {
          only_current = true,
          only_scope = true,
        },
        scope = {
          only_current = true,
          animate = {
            easing = "inQuad",
            duration = { total = 100 },
          },
        },
      },

      -- LazyVim integration
      lazygit = {
        ---@type snacks.lazygit.Theme|{}
        theme = {
          selectedLineBgColor = { bg = "PmenuSel" },
        },
        win = {
          height = 0,
          width = 0,
          backdrop = false,
        },
      },

      -- Notifications
      notifier = {
        top_down = false,
      },

      -- Picker
      picker = {
        formatters = {
          file = {
            -- filename_first = true,
          },
        },

        ---@type snacks.picker.icons.Config|{}
        icons = {
          ui = {
            hidden = "󰘓 ",
            ignored = "󰷊 ",
            follow = " ",
          },
        },

        layouts = {
          lg = {
            layout = {
              box = "horizontal",
              row = -1,
              width = 0,
              height = 0.51,
              min_height = 20,
              {
                box = "vertical",
                border = "right",
                {
                  win = "input",
                  height = 1,
                  border = border.topPad,
                  title = "{source} {live} {flags}",
                  title_pos = "center",
                },
                {
                  win = "list",
                  border = "top",
                  wo = wo.snacks.picker.list,
                },
              },
              {
                win = "preview",
                title = "{preview}",
                title_pos = "center",
                width = 0.56,
                border = "vpad",
                minimal = true,
                wo = wo.snacks.picker.preview,
              },
            },
          },

          sm = {
            fullscreen = true,
            layout = {
              box = "vertical",
              border = "none",
              {
                win = "preview",
                title = "{preview}",
                title_pos = "center",
                height = 0.5,
                border = "top",
                minimal = true,
                wo = wo.snacks.picker.preview,
              },
              {
                box = "vertical",
                { win = "input", height = 1, border = "top", title = "{source} {live} {flags}", title_pos = "center" },
                {
                  win = "list",
                  border = "top",
                  wo = wo.snacks.picker.list,
                },
              },
            },
          },
        },

        layout = {
          cycle = true,
          preset = responsiveLayout,
        },

        previewers = {
          diff = { builtin = false },
          git = { builtin = false },
        },

        sources = {
          buffer = { hidden = false, preview = update_picker_preview_file_title },
          explorer = { hidden = true },
          files = { hidden = true, preview = update_picker_preview_file_title },
          git_grep = { hidden = true, preview = update_picker_preview_file_title },
          grep = { hidden = true, preview = update_picker_preview_file_title },
          grep_buffers = { hidden = true, preview = update_picker_preview_file_title },
          grep_word = { hidden = true, preview = update_picker_preview_file_title },
          smart = { filter = { cwd = true }, preview = update_picker_preview_file_title },
        },

        win = {
          input = { keys = pickerWinCommonKeymaps },
          list = { keys = pickerWinCommonKeymaps },
          preview = { keys = pickerWinCommonKeymaps },
        },
      },

      -- Scroll Animation
      scroll = {
        animate = {
          duration = { total = 100 },
        },
      },

      -- Status Column
      statuscolumn = {
        left = { "sign", "git" },
        right = { "mark", "fold" },
      },

      -- Zen Mode
      zen = {
        on_open = function() toggleFontSize(true) end,
        on_close = function() toggleFontSize(false) end,

        toggles = {
          dim = true,
          -- git_signs = false,
          -- mini_diff_signs = false,
          indent = false,
          -- diagnostics = false,
          -- inlay_hints = false,
        },

        win = {
          backdrop = { transparent = false, bg = require("catppuccin.palettes").get_palette().base },
        },
      },
    },

    keys = {
      {
        "<leader><space>",
        function() Snacks.picker.smart() end,
        desc = "Find Files (Root Dir)",
      },
      {
        "<leader>fe",
        function() Snacks.explorer() end,
        desc = "File Explorer (cwd)",
      },
      {
        "<leader>fE",
        function() Snacks.explorer({ cwd = LazyVim.root() }) end,
        desc = "File Explorer (root dir)",
      },
    },
  },
}
