---@module 'lazy'
---@module 'mason'
---@module 'otter'
---@module 'render-markdown'

local left_pad = 2

local mason_tools_to_remove = {
  "markdownlint-cli2",
  "rumdl",
}

---@type LazySpec
return {
  {
    "mason-org/mason.nvim",

    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      for index, tool in ipairs(opts.ensure_installed) do
        if vim.list_contains(mason_tools_to_remove, tool) then table.remove(opts.ensure_installed, index) end
      end
    end,
  },

  {
    "stevearc/conform.nvim",
    optional = true,
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {
        markdown = { "rumdl" },
        ["markdown.mdx"] = { "rumdl" },
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
    end,
  },

  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      servers = {
        rumdl = {
          mason = false,
          filetypes = { "markdown", "markdown.mdx" },
        },
      },
    },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
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
        icons = { "h1. ", "h2. ", "h3. ", "h4. ", "h5. ", "h6. " },
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
  },
}
