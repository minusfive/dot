---@module 'lazy'
---@module 'snacks'

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",

    ---@type PluginLspOpts
    opts = {
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
            get = function() return #MinusfiveUtils.getLSPClientsByName("harper_ls") > 0 end,
            set = function() MinusfiveUtils.toggleLSPClient("harper_ls") end,
          }):map("<leader>lg")
        end,
      },
    },
  },
}
