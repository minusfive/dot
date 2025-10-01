return {
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },

  {
    "catppuccin/nvim",
    name = "catppuccin",

    ---@module 'catppuccin'
    ---@type CatppuccinOptions|{}
    opts = {
      transparent_background = true,
      dim_inactive = {
        enabled = true,
        percentage = 0.05,
      },

      highlight_overrides = {
        all = function(colors)
          local utils = require("catppuccin.utils.colors")

          ---Define alpha function to adjust color transparency
          ---@param color string Color name or hex value
          ---@param transparency number Alpha value (0-1)
          ---@param base string? Base color to blend with (optional)
          ---@return string Color blended color
          local function alpha(color, transparency, base) return utils.blend(color, base or colors.base, transparency) end

          local search_hl = { bg = alpha(colors.rosewater, 0.2), fg = colors.peach }

          return {
            -- Base
            Normal = { fg = colors.subtext1 },
            CursorColumn = { link = "CursorLine" },
            CursorLine = { bg = colors.mantle },
            CursorLineNr = { link = "CursorLine", style = { "bold" } },
            CursorLineSign = { link = "CursorLine" },
            Folded = { bg = colors.surface0 },

            -- Visual selections with inverted colors matching lualine mode bg
            Visual = { bg = alpha(colors.mauve, 0.15), fg = colors.mauve, style = { "bold" } },
            VisualNOS = { link = "Visual" },

            -- Floating Windows
            NormalFloat = { bg = colors.base },
            FloatTitle = { link = "NormalFloat" },
            FloatBorder = { fg = colors.surface1, bg = colors.base },
            FloatShadow = { bg = 0, blend = 80, ctermbg = 0 },
            FloatShadowThrough = { bg = 0, blend = 100, ctermbg = 0 },
            Pmenu = { link = "NormalFloat" },
            PmenuSel = { bg = colors.surface0 },
            PmenuSbar = { link = "PmenuSel" },
            PmenuThumb = { bg = colors.surface1 },

            -- Search
            Search = { bg = search_hl.bg, fg = search_hl.fg, style = { "underline" } },
            IncSearch = { link = "Search" },
            CurSearch = { bg = search_hl.bg, fg = colors.yellow, style = { "bold", "underline" } },
            SearchCount = { fg = colors.peach },
            FlashBackdrop = { fg = colors.overlay1 },
            FlashMatch = { bg = search_hl.bg, fg = colors.peach },
            FlashLabel = { bg = alpha(colors.teal, 0.2), fg = colors.teal },
            FlashPromptIcon = { bg = colors.peach, fg = colors.mantle },
            FlashCurrent = { bg = search_hl.bg, fg = colors.yellow, style = { "bold", "underline" } },

            -- Custom cursor colors per mode
            MCursorInsert = { bg = colors.green, fg = colors.mantle },
            MCursorNormal = { bg = colors.blue, fg = colors.mantle },
            MCursorVisual = { bg = colors.mauve, fg = colors.mantle },
            MCursorReplace = { bg = colors.red, fg = colors.mantle },
            MCursorCommand = { bg = colors.peach, fg = colors.mantle },

            -- Dashboard
            SnacksDashboardDesc = { fg = "" },
            SnacksDashboardFile = { fg = "" },
            SnacksDashboardFooter = { fg = colors.surface2 },
            SnacksDashboardHeader = { fg = colors.sky },
            SnacksDashboardIcon = { fg = colors.teal },
            SnacksDashboardKey = { fg = colors.teal, style = { "bold" } },
            SnacksDashboardSpecial = { fg = colors.overlay1 },
            SnacksDashboardTitle = { fg = colors.surface1, style = { "underline" } },

            -- Text Dimming
            SnacksDim = { fg = colors.surface2, style = {} },

            -- Indentation Lines
            SnacksIndent = { fg = colors.surface0 },
            SnacksIndentScope = { fg = colors.surface1 },
            SnacksIndentChunk = { fg = colors.surface1 },

            -- Picker
            SnacksPickerTitle = { bg = colors.peach, fg = colors.mantle, style = { "bold" } },
            SnacksPickerCursorLine = { link = "PmenuSel" },
            SnacksPickerListCursorLine = { link = "SnacksPickerCursorLine" },
            SnacksPickerListItemSign = { fg = colors.base },
            SnacksPickerListItemSignCursorLine = { bg = colors.surface0, fg = colors.peach },
            SnacksPickerMatch = { fg = "", style = { "underline" } },
            SnacksPickerPreviewCursorLine = { link = "SnacksPickerCursorLine" },
            SnacksPickerPreviewTitle = { bg = colors.sapphire, fg = colors.base, style = { "bold" } },
            SnacksPickerPrompt = { link = "Command" },
            SnacksPickerSelected = { bg = "", fg = colors.peach },
            SnacksPickerToggle = { bg = colors.flamingo, fg = colors.base, style = { "italic" } }, ---Title flags indicators

            -- Command utils themed with command mode colors (orange-ish)
            Command = { fg = colors.peach },
            NoiceCmdlineIcon = { bg = colors.peach, fg = colors.mantle },
            NoiceCmdlineIconSearch = { bg = colors.peach, fg = colors.mantle },
            NoiceCmdlinePopupBorder = { fg = colors.peach },
            NoiceCmdlinePopupTitle = { fg = colors.peach },

            -- Completion
            BlinkCmpItemIdx = { fg = colors.surface2 },
            BlinkCmpLabelMatch = { fg = colors.yellow },
            BlinkCmpDoc = { link = "Pmenu" },
            BlinkCmpDocBorder = { link = "FloatBorder" },
            BlinkCmpDocSeparator = { link = "BlinkCmpDoc" },
            BlinkCmpMenuBorder = { link = "FloatBorder" },
            BlinkCmpMenuSelection = { link = "PmenuSel" },
            BlinkCmpScrollbarThumb = { link = "PmenuThumb" },

            -- LSP (e.g. reference highlighting like Snacks.words, vim-illuminate, etc.)
            LspReferenceText = { bg = colors.surface0 },
            LspReferenceRead = { bg = colors.surface0 },
            LspReferenceWrite = { bg = colors.surface0 },
            LspReferenceTarget = { bg = colors.surface0 },

            -- Markdown Rendering
            ["@markup.heading.1.markdown"] = { fg = colors.yellow, style = { "bold" } },
            ["@markup.heading.2.markdown"] = { fg = colors.green, style = { "bold" } },
            ["@markup.heading.3.markdown"] = { fg = colors.teal, style = { "bold" } },
            ["@markup.heading.4.markdown"] = { fg = colors.sky, style = { "bold" } },
            ["@markup.heading.5.markdown"] = { fg = colors.sapphire, style = { "bold" } },
            ["@markup.heading.6.markdown"] = { fg = colors.lavender, style = { "bold" } },
            ["@markup.heading.markdown"] = { fg = colors.text, style = { "bold" } }, --- Table headings
            ["@markup.italic.markdown_inline"] = { fg = "", style = { "italic" } },
            ["@markup.link"] = { fg = colors.overlay2 },
            ["@markup.link.label"] = { fg = colors.blue },
            ["@markup.link.url"] = { fg = colors.sapphire, style = { "italic", "underline" } },
            ["@markup.list"] = { fg = alpha(colors.lavender, 0.6) },
            ["@markup.quote"] = { fg = "" },
            ["@markup.raw.markdown_inline"] = { fg = colors.text, style = { "italic" } },
            ["@markup.strong.markdown_inline"] = { fg = colors.text, style = { "bold" } },
            RenderMarkdownBullet = { link = "@markup.list" },
            RenderMarkdownH1 = { link = "@markup.heading.1.markdown" },
            RenderMarkdownH1Bg = { bg = alpha(colors.green, 0.075) },
            RenderMarkdownH2 = { link = "@markup.heading.2.markdown" },
            RenderMarkdownH2Bg = { bg = alpha(colors.teal, 0.075) },
            RenderMarkdownH3 = { link = "@markup.heading.3.markdown" },
            RenderMarkdownH3Bg = { bg = alpha(colors.sky, 0.075) },
            RenderMarkdownH4 = { link = "@markup.heading.4.markdown" },
            RenderMarkdownH4Bg = { bg = alpha(colors.sapphire, 0.075) },
            RenderMarkdownH5 = { link = "@markup.heading.5.markdown" },
            RenderMarkdownH5Bg = { bg = alpha(colors.blue, 0.075) },
            RenderMarkdownH6 = { link = "@markup.heading.6.markdown" },
            RenderMarkdownH6Bg = { bg = alpha(colors.lavender, 0.05) },
            RenderMarkdownQuote1 = { fg = alpha(colors.lavender, 0.4) },
            RenderMarkdownQuote2 = { link = "RenderMarkdownQuote1" },
            RenderMarkdownQuote3 = { link = "RenderMarkdownQuote1" },
            RenderMarkdownQuote4 = { link = "RenderMarkdownQuote1" },
            RenderMarkdownQuote5 = { link = "RenderMarkdownQuote1" },
            RenderMarkdownQuote6 = { link = "RenderMarkdownQuote1" },
            RenderMarkdownTableFill = { fg = "", bg = "" },
            RenderMarkdownTableHead = { fg = alpha(colors.lavender, 0.4), bg = "" },
            RenderMarkdownTableRow = { fg = alpha(colors.lavender, 0.4), bg = "" },
          }
        end,
      },

      integrations = {
        dap = true,
        dap_ui = true,
      },
    },
  },

  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    enabled = false,
    opts = {
      dim_inactive = true,
      lualine_bold = true,
      style = "night",

      styles = {
        sidebars = "dark",
        floats = "dark",
        -- sidebars = "transparent",
        -- floats = "transparent",
      },

      -- transparent = true,
      use_background = "dark",

      on_colors = function(colors) colors.border_highlight = colors.dark3 end,

      on_highlights = function(highlights, colors)
        highlights.CursorLine.bg = colors.bg_dark
        highlights.NoiceCmdlineIcon = highlights.DinosticWarn
        highlights.NoiceCmdlinePopupBorder = highlights.DiagnosticWarn
        highlights.NoiceCmdlinePopupTitle = highlights.DiagnosticWarn
        highlights.DashboardFooter.fg = colors.blue0
        highlights.TreesitterContext.bg = highlights.BufferTabpageFill.bg
      end,
    },
  },

  {
    "ntk148v/habamax.nvim",
    name = "habamax",
    enabled = false,
  },
}
