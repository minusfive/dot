---@module 'blink.cmp'
---@module 'codecompanion'
---@module 'copilot'
---@module 'lazy'
---@module 'mason-lspconfig'
---@module 'mcphub'
---@module 'snacks'
-- TODO: Explore LuaLine integration

---@type LazySpec
return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,

    ---@type CopilotConfig|{}
    opts = {
      server = {
        type = "binary",
      },
    },
  },

  {
    "saghen/blink.cmp",
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
    },
    cmd = { "CodeCompanion" },
    opts = {
      log_level = "DEBUG",

      adapters = {
        copilot = function()
          return require("codecompanion.adapters").extend("copilot", {
            schema = {
              model = {
                default = "gpt-5-mini",
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
      },

      extensions = {
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
              model = "gpt-5-mini",
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
      },

      interactions = {
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

          roles = {
            ---@type string|fun(adapter: CodeCompanion.HTTPAdapter|CodeCompanion.ACPAdapter): string
            llm = function(adapter) return adapter.formatted_name end,
          },

          tools = {
            opts = {
              default_tools = { "mcp" },
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

      prompt_library = {
        markdown = {
          dirs = {
            vim.fn.getcwd() .. "/.ai/prompts",
            vim.env.XDG_CONFIG_HOME .. "/ai/prompts/codecompanion",
          },
        },
      },

      rules = {
        opts = {
          chat = {
            autoload = function()
              local is_work = require("util").cwd_is_descendant_of_dir(vim.env.HOME .. "/dev/work")
              if is_work then return { "default", "work" } end
              return "default"
            end,
          },
        },

        work = {
          description = "Global memory files for work related projects",
          files = {
            "~/dev/work/AGENTS.md",
          },
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
    config = true,
    lazy = false,
    cmd = { "MCPHub" },
    ---@type MCPHub.Config
    opts = {
      workspace = {
        look_for = { ".mcphub/servers.json", ".vscode/mcp.json", ".cursor/mcp.json", ".ai/mcp/servers.json" },
      },
      log = {
        -- level = vim.log.levels.DEBUG,
      },
    },
    keys = {
      {
        "<leader>am",
        "<cmd>MCPHub<cr>",
        desc = "MCP Hub",
        mode = { "n", "v" },
      },
    },
  },
}
