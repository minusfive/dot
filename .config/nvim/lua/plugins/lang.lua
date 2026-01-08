---@module 'lazy'

local win_diagnostics_opts = {
  max_width = 0.9, -- 90% of the main window width
  max_height = 0.9, -- 90% of the main window height
}

local function calc_max_dimensions()
  -- Calculate max_width and max_height as a percentage of the main window's dimensions
  local main_win = vim.api.nvim_get_current_win()
  local width = vim.api.nvim_win_get_width(main_win)
  local height = vim.api.nvim_win_get_height(main_win)

  return {
    max_width = math.floor(width * win_diagnostics_opts.max_width),
    max_height = math.floor(height * win_diagnostics_opts.max_height),
  }
end

---Store original `vim.lsp.util.open_floating_preview` function
local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview

---Intercept `vim.lsp.util.open_floating_preview` to set default options
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  local max_dimensions = calc_max_dimensions()
  opts = opts or {}
  opts.max_width = opts.max_width or max_dimensions.max_width
  opts.max_height = opts.max_height or max_dimensions.max_height
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      diagnostics = {
        severity_sort = true,
        virtual_text = false,
        virtual_lines = false,

        float = {
          style = "minimal",
          border = "rounded",
          source = "always",
          severity_sort = true,
          header = "",
          prefix = " ",
          suffix = " ",
        },
      },
      inlay_hints = { enabled = false },
    },
    keys = {
      { "<leader>li", "<cmd>:LspInfo<cr>", desc = "Info" },
      { "<leader>ll", "<cmd>:LspLog<cr>", desc = "Log" },
      { "<leader>lr", "<cmd>:LspRestart<cr>", desc = "Restart" },
    },
  },

  { import = "plugins/lang" },
}
