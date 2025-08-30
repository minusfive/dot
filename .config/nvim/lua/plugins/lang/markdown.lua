local left_pad = 2

---@type LazySpec
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      -- anti_conceal = {
      --   ignore = {
      --     indent = false,
      --     virtual_lines = false,
      --   },
      -- },

      bullet = {
        left_pad = 0,
        right_pad = 0,
        icons = { "╸" },
      },

      checkbox = {
        enabled = true,
        custom = {
          todo = { raw = "[-]", rendered = "󰥔  ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
          done = { raw = "[x]", rendered = "  ", highlight = "RenderMarkdownDone", scope_highlight = nil },
          rightarrow = {
            raw = "[>]",
            rendered = "  ",
            highlight = "RenderMarkdownRightArrow",
            scope_highlight = nil,
          },
          tilde = { raw = "[~]", rendered = "󰰱  ", highlight = "RenderMarkdownTilde", scope_highlight = nil },
          important = { raw = "[!]", rendered = "  ", highlight = "RenderMarkdownImportant", scope_highlight = nil },
        },
      },

      code = {
        -- style = "full",
        above = "█",
        below = "█",
        language_border = "█",
        language_pad = 0,
        left_pad = left_pad + 1,
        -- right_pad = 0,
        width = "full",

        -- These affect how backtick lines are rendered
        border = "thick",
        conceal_delimiters = false,
        language = true,

        -- inline
        -- inline_left = " ",
        -- inline_right = " ",
        inline_pad = 1,
      },

      completions = { lsp = { enabled = true } },

      heading = {
        icons = { "▉ ", "▍▍ ", "▏▏▏ ", "▏▏▏▏ ", "▏▏▏▏▏ ", "▏▏▏▏▏▏ " },
        border = false,
        border_prefix = false,
        border_virtual = false,
        position = "inline",
        above = "▂",
        below = "🮂",
      },

      link = {
        custom = {
          confluence = { pattern = "wiki%.autodesk%.com", icon = " " },
          jira = { pattern = "jira%.autodesk%.com", icon = "󰌃 " },
          markdown = { pattern = "%.md$", icon = " " },
          javascript = { pattern = "%.js$", icon = "󰌞 " },
          typescript = { pattern = "%.ts$", icon = "󰛦 " },
          json = { pattern = "%.json5?$", icon = "󰘦 " },
          python = { pattern = "%.py$", icon = "󰌠 " },
          ruby = { pattern = "%.rb$", icon = " " },
          excel = { pattern = "share%.autodesk%.com%/%:x%:%/", icon = "󱎏 " },
          word = { pattern = "share%.autodesk%.com%/%:w%:%/", icon = "󱎒 " },
        },
      },

      paragraph = {},

      pipe_table = {
        cell = "trimmed",
      },

      quote = {
        icon = "▍ ",
        repeat_linebreak = true,
      },
    },
  },

  {
    "jmbuhr/otter.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    -- ---@module 'otter'
    -- ---@type OtterConfig
    -- opts = {},
  },
}
