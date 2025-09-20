---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = { groovyls = {} },
    },
  },
}
