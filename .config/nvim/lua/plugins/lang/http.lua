---@type LazySpec
return {
  {
    "mistweaverco/kulala.nvim",
    branch = "develop",
    keys = {
      {
        "<leader>Ra",
        "<cmd>lua require('kulala.ui.auth_manager').open_auth_config()<cr>",
        desc = "Auth Manager",
        ft = "http",
      },
      { "<leader>Re", "<cmd>lua require('kulala').set_selected_env()<cr>", desc = "Env Select", ft = "http" },
      { "<leader>Ro", "<cmd>lua require('kulala').open()<cr>", desc = "Open Kulala", ft = "http" },
    },
    opts = {
      environment_scope = "g",
      ui = {
        icons = {
          inlay = {
            loading = "󰦖 ",
            done = "󰸞 ",
            error = "󱇎 ",
          },
          lualine = "󱂛 ",
        },

        pickers = {
          snacks = {
            layout = {},
          },
        },
      },
    },
  },
}
