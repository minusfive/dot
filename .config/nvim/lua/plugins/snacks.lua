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

return {
  {
    "folke/snacks.nvim",
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

      -- Indentation guides
      indent = {
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

      -- Picker
      picker = {
        layout = {
          cycle = true,
          preset = responsiveLayout,
        },

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

        formatters = {
          file = {
            filename_first = true,
          },
        },

        sources = {
          explorer = {
            hidden = true,
          },
          files = {
            hidden = true,
          },
          grep = {
            hidden = true,
          },
          smart = {
            hidden = true,
            filter = { cwd = true },
          },
        },

        win = {
          input = {
            keys = pickerWinCommonKeymaps,
          },
          list = {
            keys = pickerWinCommonKeymaps,
          },
          preview = {
            keys = pickerWinCommonKeymaps,
          },
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
    },

    keys = {
      {
        "<leader><space>",
        function() Snacks.picker.smart() end,
        desc = "Find Files (Root Dir)",
      },
    },
  },
}
