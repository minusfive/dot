--- Keymap Group: Lazy
local kmg_lazy = "<leader>L"

--- Only enable `treesj` keymaps for supported languages
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = "*",
  callback = function()
    if not LazyVim.has("treesj") then return end
    local opts = { buffer = true }
    local cmd = "join"
    if require("treesj.langs")["presets"][vim.bo.filetype] then cmd = "TSJToggle" end
    vim.keymap.set("n", "<leader>j", "<cmd>" .. cmd .. "<cr>", opts)
    vim.keymap.set("v", "<leader>j", "<cmd>'<,'>" .. cmd .. "<cr>", opts)
  end,
})

---@module "trouble"
---@type trouble.Mode|{}
local shared_trouble_bottom_modes_config = {
  win = {
    size = 30,
  },
}

---@type LazySpec
return {
  --- Search and Replace UI
  --- Unnecessary as qflist and cdo natively support this
  {
    "MagicDuck/grug-far.nvim",
    enabled = false,
  },

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
    opts = {
      use_default_keymaps = false,
      max_join_length = 120,
    },
  },

  -- Labeled search
  {
    "folke/flash.nvim",
    ---@module "flash"
    ---@type Flash.Config
    opts = {
      prompt = {
        prefix = { { " 󱌯   ", "FlashPromptIcon" }, { " " } },
      },
    },
  },

  -- Diagnostics
  {
    "folke/trouble.nvim",
    optional = true,
    ---@type trouble.Config
    opts = {
      ---@type table<string, trouble.Mode|{}>
      modes = {
        qflist = shared_trouble_bottom_modes_config,
        diagnostics = shared_trouble_bottom_modes_config,
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

  -- Lua types
  {
    "folke/lazydev.nvim",
    dependencies = {
      {
        "DrKJeff16/wezterm-types",
        lazy = true,
        version = false, -- Get the latest version
      },
    },
    opts = {
      library = {
        -- Other library configs...
        { path = "wezterm-types", mods = { "wezterm" } },
      },
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
