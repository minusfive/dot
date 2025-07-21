local left_pad = 2

-- From: https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/311
local function find_all(buf, node, pattern)
  local start_row, _, end_row, _ = node:range()
  end_row = end_row + (start_row == end_row and 1 or 0)
  local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)
  local result = {}
  for row, line in ipairs(lines) do
    ---@type integer|nil
    local index = 1
    while index ~= nil do
      local start_index, end_index = line:find(pattern, index)
      if start_index == nil or end_index == nil then
        index = nil
      else
        table.insert(result, {
          row = start_row + row - 1,
          col = { start_index - 1, end_index },
        })
        index = end_index + 1
      end
    end
  end
  return result
end
local function mark(match, text)
  return {
    conceal = true,
    start_row = match.row,
    start_col = match.col[1],
    opts = {
      end_col = match.col[2],
      conceal = "",
      virt_text = { { text, "DiagnosticOk" } },
      virt_text_pos = "inline",
    },
  }
end
local function render_dashes(root, buf)
  local query =
    vim.treesitter.query.parse("markdown_inline", '((inline) @replacements (#lua-match? @replacements "[%.%-][%.%-]"))')
  local result = {}
  for _, node in query:iter_captures(root, buf) do
    local _, start_col, _, _ = node:range()
    if start_col == 0 then
      -- 3 or more dots
      local ellipses = find_all(buf, node, "%.%.%.+")
      for _, ellipse in ipairs(ellipses) do
        table.insert(result, mark(ellipse, "…"))
      end
      -- 2 or more hyphens
      local dashes = find_all(buf, node, "%-%-+")
      for _, dash in ipairs(dashes) do
        local width = dash.col[2] - dash.col[1]

        local ems = math.floor(width / 3)
        width = math.fmod(width, 3)

        local ens = math.floor(width / 2)
        width = math.fmod(width, 2)

        local text = string.rep("—", ems) .. string.rep("–", ens) .. string.rep("-", width)

        table.insert(result, mark(dash, text))
      end
    end
  end
  return result
end
---@type LazySpec
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      anti_conceal = {
        ignore = {
          indent = false,
          virtual_lines = false,
        },
      },

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
        language_border = "█",
        language_pad = 0,
        left_pad = left_pad + 1,
        right_pad = 0,
        width = "full",

        -- These affect how backtick lines are rendered
        border = "thick",
        conceal_delimiters = false,
        language = true,
      },

      custom = {
        -- This is used to render dashes and ellipses
        markdown_inline = {
          extends = true,
          parse = render_dashes,
        },
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

      pipe_table = {
        cell = "trimmed",
      },

      quote = {
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
