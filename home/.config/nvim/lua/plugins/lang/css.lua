---@module 'lazy'
---@module 'snacks'

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",

    ---@type PluginLspOpts
    opts = {
      servers = {
        cssls = {},
        css_variables = {},
        cssmodules_ls = {
          init_options = {
            camelCase = false,
          },
        },
        stylelint_lsp = {},
      },
    },
  },
}
