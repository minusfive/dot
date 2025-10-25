---@module 'lazy'

---@type LazySpec
return {
  {
    "apple/pkl-neovim",
    ft = "pkl",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        opts = {
          ensure_installed = { "pkl" },
        },
      },
    },

    init = function()
      vim.g.pkl_neovim = {
        start_command = { "pkl-lsp" },
        pkl_cli_path = "pkl",
      }
    end,
  },
}
