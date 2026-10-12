return {
  {
    "stevearc/conform.nvim",
    optional = true,
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = { zsh = { "beautysh" } },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "beautysh" },
    },
  },
}
