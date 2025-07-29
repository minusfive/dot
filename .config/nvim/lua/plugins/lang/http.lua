---@type LazySpec
return {
  {
    "mistweaverco/kulala.nvim",
    branch = "develop",
    keys = {
      { "<leader>Ra", "<cmd>lua require('kulala').run_all()<cr>", desc = "Send all requests", ft = "http" },
      {
        "<leader>RA",
        "<cmd>lua require('kulala.ui.auth_manager').open_auth_config()<cr>",
        desc = "Auth Manager",
        ft = "http",
      },
      { "<leader>Re", "<cmd>lua require('kulala').set_selected_env()<cr>", desc = "Env Select", ft = "http" },
      { "<leader>Ro", "<cmd>lua require('kulala').open()<cr>", desc = "Open Kulala", ft = "http" },
    },

    opts = {
      environment_scope = "g",

      kulala_keymaps = {
        -- Defaults:
        -- - Previous response: `[`
        -- - Next response: `]`
        -- - Show filter: `F`
        -- - Show report: `R`
        -- - Show script output: `O`
        -- - Show verbose: `V`
        -- - Show headers and body: `A`
        -- - Show body: `B`
        -- - Show headers: `H`
        -- - Show stats: `S`
        -- - Show news: `g?`
        -- - Close: `q`
        -- - Show help: `?`
        -- - Interrupt requests: `<C-c>`
        -- - Send WS message: `<S-CR>`
        -- - Clear responses history: `X`
        -- - Jump to response: `<CR>`

        -- Overrides
        ["Show body"] = { "<a-b>", function() require("kulala.ui").show_body() end },
        ["Show filter"] = { "<a-f>", function() require("kulala.ui").toggle_filter() end },
        ["Show headers and body"] = { "<a-a>", function() require("kulala.ui").show_headers_body() end },
        ["Show headers"] = { "<a-h>", function() require("kulala.ui").show_headers() end },
        ["Show script output"] = { "<a-o>", function() require("kulala.ui").show_script_output() end },
        ["Show report"] = { "<a-r>", function() require("kulala.ui").show_report() end },
        ["Show stats"] = { "<a-i>", function() require("kulala.ui").show_stats() end },
        ["Show verbose"] = { "<a-v>", function() require("kulala.ui").show_verbose() end },
        ["Show help"] = { "?", function() require("which-key").show({ global = false }) end },
      },

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
