-- Notifications, command pop-ups, etc.
local nui_options = {
  popup = {
    win_options = {
      winblend = 5,
    },
  },
}

local function getcwd() return vim.fn.fnamemodify(vim.fn.getcwd(), ":t") end

local lualine_vectorcode = {
  function() return require("vectorcode.integrations").lualine({ show_job_count = true })[1]() end,
  cond = function()
    if package.loaded["vectorcode"] == nil then
      return false
    else
      return require("vectorcode.integrations").lualine({ show_job_count = true }).cond()
    end
  end,
}

local lualine_obsidian_vault = {
  function() return "vault: " .. require("obsidian").get_client():vault_name() end,
  cond = function()
    if package.loaded["obsidian"] == nil then
      return false
    else
      return not not require("obsidian").get_client():vault_name()
    end
  end,
}

return {
  -- Disable defaults
  { "lukas-reineke/indent-blankline.nvim", enabled = false }, -- Replaced by Snacks.indent

  -- Notification messages
  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      cmdline = {
        view = "cmdline",
        format = {
          calculator = { icon = "   " },
          cmdline = { icon = "   " },
          filter = { icon = "   " },
          help = { icon = "    " },
          help_vert = { kind = "Help", pattern = "^:%s*verti?c?a?l? he?l?p?%s+", icon = "    " },
          inc_rename = { kind = "IncRename", pattern = "^:IncRename", icon = " 󰑕  " },
          lua = { icon = "   " },
          search_down = { icon = " 󰶹   " },
          search_up = { icon = " 󰶼   " },
        },
      },
      presets = {
        bottom_search = true,
        command_palette = false,
        inc_rename = false,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
      views = {
        cmdline_popupmenu = nui_options.popup,
        confirm = nui_options.popup,
        hover = nui_options.popup,
        popup = nui_options.popup,
        popupmenu = nui_options.popup,
      },
    },
  },

  -- Animation enhancements
  {
    "sphamba/smear-cursor.nvim",
    optional = true,
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.3,
      legacy_computing_symbols_support = true,
    },
  },

  -- Statusline, Winbar and Bufferline (buffer tabs) configuration
  {
    "nvim-lualine/lualine.nvim",
    optional = true,

    opts = function(_, opts)
      -- Theme
      local colors = require("catppuccin.palettes").get_palette("mocha")
      local cst = require("catppuccin.utils.lualine")("mocha")
      cst.normal.b.bg = colors.base
      cst.normal.c.bg = colors.base
      opts.options.theme = cst

      -- local icons = require("lazyvim.config").icons
      local c = opts.sections.lualine_c
      local diagnostics = c[2]
      local file_type_icon = c[3]
      -- local pretty_path = c[4]
      -- local root_dir = c[1]
      local symbols = c[5]

      local x = opts.sections.lualine_x
      local cmd = table.remove(x, 1)
      local diff = table.remove(x)

      cmd.color = "Command"

      opts.options.component_separators = { "", "" }
      opts.options.section_separators = { "", "" }

      opts.sections.lualine_a = {}
      opts.sections.lualine_b = { "%l:%c", "%p%%", lualine_obsidian_vault, "g:obsidian" }
      opts.sections.lualine_c = { cmd }
      opts.sections.lualine_y = { lualine_vectorcode, getcwd, "branch" }
      opts.sections.lualine_z = {}

      vim.list_extend(
        opts.options.disabled_filetypes.statusline,
        { "neo-tree", "edgy", "snacks_picker_input", "snacks_picker_list", "snacks_picker_preview" }
      )

      opts.options.disabled_filetypes.winbar = vim.list_extend({}, opts.options.disabled_filetypes.statusline)

      opts.winbar = {
        lualine_a = {
          {
            "bo:modified",
            fmt = function(output) return output == "true" and "󱇧" or nil end,
            color = { bg = colors.yellow },
          },
          {
            "bo:readonly",
            fmt = function(output) return output == "true" and "󰈡" or nil end,
            color = { bg = colors.red },
          },
          {
            "mode",
            fmt = function(str) return str:sub(1, 1) end,
          },
        },

        lualine_b = {
          file_type_icon,
          { "filename", file_status = false, path = 1 },
        },
        lualine_c = { symbols },
        lualine_x = {
          { "searchcount", color = "SearchCount" },
          diagnostics,
          diff,
        },
      }

      opts.inactive_winbar = {
        lualine_c = opts.winbar.lualine_b,
        lualine_x = opts.winbar.lualine_x,
      }
    end,
  },

  -- Bufferline (buffer tabs)
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  -- Hide Secrets
  {
    "laytan/cloak.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      opts.cloak_length = 5
      opts.cloak_on_leave = true

      require("which-key").add({
        { "<leader>*", group = "Cloak", icon = LazyVim.config.icons.misc.dots },
        { "<leader>*l", "<cmd>CloakPreviewLine<cr>", desc = "Uncloak Line" },
      })

      Snacks.toggle({
        name = "Cloak",
        get = function() return vim.b.cloak_enabled ~= false end,
        set = function() require("cloak").toggle() end,
      }):map("<leader>**")
    end,
  },
}
