return {
  "MeanderingProgrammer/render-markdown.nvim",
  optional = true,
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    checkbox = {
      enabled = true,
      custom = {
        todo = { raw = "[-]", rendered = "󰥔  ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
        done = { raw = "[x]", rendered = "  ", highlight = "RenderMarkdownDone", scope_highlight = nil },
        rightarrow = { raw = "[>]", rendered = "  ", highlight = "RenderMarkdownRightArrow", scope_highlight = nil },
        tilde = { raw = "[~]", rendered = "󰰱  ", highlight = "RenderMarkdownTilde", scope_highlight = nil },
        important = { raw = "[!]", rendered = "  ", highlight = "RenderMarkdownImportant", scope_highlight = nil },
      },
    },
  },
}
