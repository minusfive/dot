---Retrieves an LSP client by name
---@param name string
---@return vim.lsp.Client | nil
local function getLSPClient(name) return vim.lsp.get_clients({ bufnr = 0, name = name })[1] end

---Toggles an LSP client by name
---@param name string
---@return nil
local function toggleLSPClient(name)
  local client = getLSPClient(name)
  if client then
    client:stop(true)
  else
    vim.cmd("LspStart " .. name)
  end
end

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

      ---@module 'lspconfig'
      ---@type {[string]: lspconfig.Config|{}}
      servers = {
        harper_ls = {
          autostart = false,
          settings = {
            ["harper-ls"] = {
              userDictPath = "~/.config/harper/dictionaries/user.txt",
              fileDictPath = "~/.config/harper/dictionaries/files/",
              codeActions = { forceStable = true },
            },
          },
        },
      },
      setup = {
        harper_ls = function()
          Snacks.toggle({
            name = "Grammar Checker",
            get = function() return getLSPClient("harper_ls") ~= nil end,
            set = function() toggleLSPClient("harper_ls") end,
          }):map("<leader>lg")
        end,
      },
    },
    keys = {
      { "<leader>li", "<cmd>:LspInfo<cr>", desc = "Info" },
      { "<leader>lr", "<cmd>:LspRestart<cr>", desc = "Restart" },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = function()
      --- Remove default LspInfo binding
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      table.insert(keys, { "<leader>cl", false })
    end,
  },

  { import = "plugins/lang" },
}
