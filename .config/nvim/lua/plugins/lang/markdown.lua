local left_pad = 2

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      bullet = {
        left_pad = 0,
        right_pad = 0,
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
        border = "thick",
        left_pad = left_pad + 1,
        right_pad = 0,
        language_pad = 0,
        language_border = "█",
        width = "full",
      },

      heading = {
        border = true,
        border_virtual = true,
        -- icons = { "󰲡  ", "󰲣  ", "󰲥  ", "󰲧  ", "󰲩  ", "󰲫  " },
        position = "inline",
        -- left_pad = left_pad - 1,
        -- sign = true,
        -- signs = { "󰫎 " },
      },

      paragraph = {
        left_margin = left_pad,
      },

      quote = {
        repeat_linebreak = true,
      },

      pipe_table = {
        cell = "trimmed",
      },
    },
  },
}
