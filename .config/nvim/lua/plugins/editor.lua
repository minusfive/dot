--- Keymap Group: Lazy
local kmg_lazy = "<leader>L"

return {
  -- Text manipulation
  -- TODO: give this a proper test, or remove
  {
    "tpope/vim-abolish",
    enabled = false,
    event = "VeryLazy",
  },

  -- More powerful joining of lines
  {
    "Wansmer/treesj",
    keys = {
      { "J", "<cmd>TSJToggle<cr>", desc = "Join Toggle" },
    },
    opts = {
      use_default_keymaps = false,
      max_join_length = 150,
    },
  },

  -- Git markers on sign column
  {
    "lewis6991/gitsigns.nvim",

    ---@module "gitsigns"
    ---@type Gitsigns.Config | {}
    opts = {
      numhl = false,
      linehl = false,
      culhl = true,
    },
  },

  -- Diagnostics
  {
    "folke/trouble.nvim",
    optional = true,
    ---@type trouble.Config
    opts = {
      modes = {
        qflist = {
          win = {
            size = 20,
          },
        },
      },
    },
  },

  -- Keybindings help menu
  {
    "folke/which-key.nvim",
    -- dev = true,
    optional = true,

    ---@module "which-key"
    ---@type wk.Config | {}
    opts = {
      preset = "helix",
      spec = {
        { kmg_lazy, group = "Lazy" },
        { "<leader>l", group = "LSP", icon = { icon = " ", color = "cyan" } },
      },
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
      },
      icons = {
        group = "",
      },
    },
    keys = {
      { kmg_lazy .. "c", LazyVim.news.changelog, desc = "Changelog" },
      { kmg_lazy .. "d", "<cmd>:LazyDev<cr>", desc = "Dev" },
      { kmg_lazy .. "h", "<cmd>:LazyHealth<cr>", desc = "Health" },
      { kmg_lazy .. "l", "<cmd>:Lazy<cr>", desc = "Lazy" },
      { kmg_lazy .. "x", "<cmd>:LazyExtras<cr>", desc = "Extras" },
    },
  },

  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
        },
      },
      event_handlers = {
        {
          event = "neo_tree_buffer_enter",
          handler = function()
            vim.cmd([[
              setlocal relativenumber
            ]])
          end,
        },
      },
      source_selector = {
        winbar = true,
      },
      window = {
        position = "right",
      },
    },
  },
}
