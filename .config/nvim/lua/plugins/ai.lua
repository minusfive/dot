-- TODO: Explore LuaLine integration
return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,

    ---@module 'copilot'
    ---@type CopilotConfig|{}
    opts = {
      server = {
        type = "binary",
      },
    },
  },

  {
    "saghen/blink.cmp",
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        providers = {
          copilot = {
            score_offset = 0,
          },
        },
      },
    },
  },

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      display = {
        action_palette = {
          provider = "snacks",
          opts = {
            show_default_actions = true,
            show_default_prompt_library = true,
          },
        },
      },
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true,
          },
        },
      },
      strategies = {
        chat = {
          adapter = "copilot",
          model = "claude-3-7-sonnet",
          -- tools = {
          --   ["next_edit_suggestion"] = {
          --     opts = {
          --       --- the default is to open in a new tab, and reuse existing tabs
          --       --- where possible
          --       ---@type string|fun(path: string):integer?
          --       jump_action = "tabnew",
          --     },
          --   },
          -- },
          variables = {
            ["buffer"] = {
              opts = {
                default_params = "watch", -- or 'pin'
              },
            },
          },
          keymaps = {
            close = {
              modes = {
                n = "q",
                i = "<C-q>",
              },
              index = 4,
              callback = "keymaps.close",
              description = "Close Chat",
            },
            stop = {
              modes = {
                n = "<C-c>",
                i = "<C-c>",
              },
              index = 5,
              callback = "keymaps.stop",
              description = "Stop Request",
            },
          },
        },
        inline = {
          adapter = "copilot",
          model = "claude-3-7-sonnet",
        },
        cmd = {
          adapter = "copilot",
          model = "claude-3-7-sonnet",
        },
      },
    },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      {
        "<leader>aa",
        "<cmd>CodeCompanionActions<cr>",
        desc = "Action Palette (CodeCompanion)",
        mode = { "n", "v" },
      },
      {
        "<leader>ac",
        function() return require("codecompanion").toggle() end,
        desc = "Chat (CodeCompanion)",
        mode = { "n", "v" },
      },
      {
        "<leader>ai",
        "<cmd>CodeCompanion<cr>",
        desc = "Input Prompt (CodeCompanion)",
        mode = { "n" },
      },
      {
        "<leader>ai",
        "<ESC><cmd>'<,'>CodeCompanion<cr>",
        desc = "Input Prompt (CodeCompanion)",
        mode = { "v" },
      },
    },
  },

  {
    "ravitemer/mcphub.nvim",
    build = "npm install -g mcp-hub@latest",
    config = function() require("mcphub").setup() end,
  },
}
