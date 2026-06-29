---@module 'lazy'
---@type LazySpec
return {
  { "dmmulroy/ts-error-translator.nvim" },
  {
    "nemanjamalesija/ts-expand-hover.nvim",
    ft = { "typescript", "typescriptreact" },

    opts = {
      keymaps = { hover = "<leader>th" },
    },
  },
}
