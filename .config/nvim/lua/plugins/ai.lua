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
            score_offset = -1,
          },
        },
      },
    },
  },

  {
    "olimorris/codecompanion.nvim",
    -- dev = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/codecompanion-history.nvim",
      {
        "minusfive/codecompanion-agent-rules",
        -- dev = true,
      },
    },
    --- Use a function to ensure VectorCode is loaded before CodeCompanion
    opts = function()
      return {
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = "claude-3.7-sonnet",
                },
              },
            })
          end,
        },
        display = {
          action_palette = {
            provider = "snacks",
            opts = {
              show_default_actions = true,
              show_default_prompt_library = true,
            },
          },
          chat = {
            intro_message = "",
          },
          diff = {
            provider = "mini_diff",
          },
        },
        extensions = {
          agent_rules = {
            enabled = true,
          },
          history = {
            enabled = true,
            opts = {
              -- Keymap to open history from chat buffer (default: gh)
              keymap = "gh",
              -- Keymap to save the current chat manually (when auto_save is disabled)
              save_chat_keymap = "sc",
              -- Save all chats by default (disable to save only manually using 'sc')
              auto_save = true,
              -- Number of days after which chats are automatically deleted (0 to disable)
              expiration_days = 0,
              -- Picker interface ("telescope" or "snacks" or "fzf-lua" or "default")
              picker = "snacks",
              ---On exiting and entering neovim, loads the last chat on opening chat
              continue_last_chat = false,
              ---When chat is cleared with `gx` delete the chat from history
              delete_on_clearing_chat = false,
              ---Directory path to save the chats
              dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
              ---Enable detailed logging for history extension
              enable_logging = false,
              ---Automatically generate titles for new chats
              auto_generate_title = true,
              title_generation_opts = {
                ---Adapter for generating titles (defaults to current chat adapter)
                adapter = "copilot",
                ---Model for generating titles (defaults to current chat model)
                model = "gpt-4.1",
              },
            },
          },
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              make_vars = true,
              make_slash_commands = true,
              show_result_in_chat = true,
            },
          },
          vectorcode = {
            opts = {
              add_tool = true,
              add_slash_command = true,
              ---@module "vectorcode"
              ---@type VectorCode.CodeCompanion.ToolOpts
              tool_opts = {
                max_num = { chunk = -1, document = -1 },
                default_num = { chunk = 50, document = 200 },
                include_stderr = true,
                use_lsp = true,
                auto_submit = { ls = false, query = false },
                ls_on_start = true,
                no_duplicate = true,
                chunk_mode = false,
              },
            },
          },
        },
        strategies = {
          chat = {
            adapter = "copilot",
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
            tools = {
              opts = {
                default_tools = { "neovim" },
              },
            },
          },
          inline = {
            adapter = "copilot",
          },
          cmd = {
            adapter = "copilot",
          },
        },
      }
    end,
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
        "<leader>ah",
        "<cmd>CodeCompanionHistory<cr>",
        desc = "History (CodeCompanion)",
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
    keys = {
      {
        "<leader>am",
        "<cmd>MCPHub<cr>",
        desc = "MCP Hub",
        mode = { "n", "v" },
      },
    },
  },

  {
    "Davidyz/VectorCode",
    version = "*", -- optional, depending on whether you're on nightly or release
    build = "uv tool upgrade vectorcode", -- optional but recommended. This keeps your CLI up-to-date.
    dependencies = { "nvim-lua/plenary.nvim" },
    ---@module "vectorcode"
    ---@param opts VectorCode.Opts|{}
    opts = function(_, opts)
      return {
        on_setup = {
          update = true, -- whether to update the CLI on setup
          lsp = false, -- whether to setup the LSP server
        },
      }
    end,
    keys = {
      {
        "<leader>au",
        function() return require("vectorcode").update() end,
        desc = "Update (VectorCode)",
        mode = { "n", "v" },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@module 'lspconfig'
      ---@type {[string]: lspconfig.Config|{}}
      servers = { vectorcode_server = {} },
    },
  },
}
