---@module 'obsidian'
-- Notifications, command pop-ups, etc.
local nui_options = {
  popup = {
    win_options = {
      winblend = 5,
    },
  },
}

local function getcwd() return vim.fn.fnamemodify(vim.fn.getcwd(), ":~") end

---@type LazySpec
return {
  -- Disable defaults
  { "lukas-reineke/indent-blankline.nvim", enabled = false }, -- Replaced by Snacks.indent

  -- Notification messages
  {
    "folke/noice.nvim",
    optional = true,

    ---@module 'noice'
    ---@type NoiceConfig
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
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
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

  -- Markdown, HTML, ASCIIDoc, SVG Previewer
  {
    "brianhuster/live-preview.nvim",
    ft = { "markdown", "html", "svg" },

    ---@module 'live-preview'
    ---@param opts LivePreviewConfig
    opts = function()
      require("snacks.toggle")
        .new({
          name = "Preview in Browser",
          get = function() return not not require("live-preview").is_running() end,
          set = function()
            local lp = require("live-preview")
            local cmd = lp.is_running() and "close" or "start"
            vim.cmd("LivePreview " .. cmd)
          end,
        })
        :map("<leader>cp")
    end,
  },

  {
    "iamcco/markdown-preview.nvim",
    enabled = false,
  },

  -- Animation enhancements
  {
    "sphamba/smear-cursor.nvim",
    optional = true,
    -- Use native cursor shader on Ghostty
    enabled = false and not vim.g.is_term_ghostty,
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.3,
      legacy_computing_symbols_support = true,
      cursor_color = "none",
    },
  },

  -- Statusline, Winbar and Bufferline (buffer tabs) configuration
  {
    "nvim-lualine/lualine.nvim",
    optional = true,

    opts = function(_, opts)
      -- Theme
      local colors = require("catppuccin.palettes").get_palette("mocha")
      local theme = require("catppuccin.utils.lualine")("mocha")
      theme.normal.b.bg = colors.base
      theme.normal.c.bg = colors.base
      opts.options.theme = theme

      opts.options.component_separators = { "", "" }
      opts.options.section_separators = { "", "" }

      opts.sections.lualine_a = {}
      opts.sections.lualine_b = { "%l:%c", "%p%%" }
      opts.sections.lualine_c = {
        { "searchcount", color = "SearchCount" },
      }

      opts.sections.lualine_x = {
        Snacks.profiler.status(),
        {
          function() return require("noice").api.status.command.get() end,
          cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
          color = function() return { fg = Snacks.util.color("Command") } end,
        },
        {
          function() return require("noice").api.status.mode.get() end,
          cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
          color = function() return { fg = Snacks.util.color("Constant") } end,
        },
        {
          function() return "  " .. require("dap").status() end,
          cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
          color = function() return { fg = Snacks.util.color("Debug") } end,
        },
        {
          require("lazy.status").updates,
          cond = require("lazy.status").has_updates,
          color = function() return { fg = Snacks.util.color("Special") } end,
        },
      }

      opts.sections.lualine_y = { getcwd }
      opts.sections.lualine_z = { { function() return "󰎞  " .. Obsidian.workspace.name end } }

      opts.options.disabled_filetypes.winbar =
        vim.list_extend(opts.options.disabled_filetypes.winbar or {}, opts.options.disabled_filetypes.statusline)

      opts.winbar = {
        lualine_a = {
          { "mode", fmt = function(str) return str:sub(1, 1) end },
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
        },

        lualine_b = {
          { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
          { "filename", file_status = false, path = 1, padding = { left = 0, right = 0 } },
        },
        lualine_c = {},
        lualine_x = {
          "kulala",
          {
            "diagnostics",
            symbols = {
              error = LazyVim.config.icons.diagnostics.Error,
              warn = LazyVim.config.icons.diagnostics.Warn,
              info = LazyVim.config.icons.diagnostics.Info,
              hint = LazyVim.config.icons.diagnostics.Hint,
            },
          },
          { "branch", color = "Comment" },
          {
            "diff",
            symbols = {
              added = LazyVim.config.icons.git.added,
              modified = LazyVim.config.icons.git.modified,
              removed = LazyVim.config.icons.git.removed,
            },
            source = function()
              local summary = vim.b.minidiff_summary
              return summary
                and {
                  added = summary.add,
                  modified = summary.change,
                  removed = summary.delete,
                }
            end,
          },
        },
      }

      -- And allow it to be overriden for some buffer types (see autocmds)
      if vim.g.trouble_lualine and LazyVim.has("trouble.nvim") then
        local trouble = require("trouble")
        local symbols = trouble.statusline({
          mode = "symbols",
          groups = {},
          title = false,
          filter = { range = true },
          format = "{kind_icon}{symbol.name:Normal}",
          hl_group = "lualine_c_normal",
        })
        table.insert(opts.winbar.lualine_c, {
          symbols and symbols.get,
          cond = function() return vim.b.trouble_lualine ~= false and symbols.has() end,
        })
      end

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
      opts.cloak_on_leave = true
      opts.patterns = opts.patterns or {}
      table.insert(opts.patterns, {
        file_pattern = "*.private.env.json",
        cloak_pattern = { ': ".*"' },
      })

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
