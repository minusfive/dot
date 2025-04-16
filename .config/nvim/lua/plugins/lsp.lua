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
    client.stop(true)
  else
    vim.cmd("LspStart " .. name)
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      diagnostics = {
        virtual_text = {
          prefix = "",
          spacing = 1,
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
}
