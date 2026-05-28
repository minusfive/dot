-- Telescope
local Util = require("lazyvim.util")

local commands = {
  telescope = {
    file_browser = "Telescope file_browser",
    undo = "Telescope undo",
  },
}

return {
  "nvim-telescope/telescope.nvim",
  optional = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Browse files with telescope
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      config = function() require("telescope").load_extension("fzf") end,
    },
    {
      "nvim-telescope/telescope-file-browser.nvim",
      event = "VeryLazy",
      config = function()
        Util.on_load("telescope.nvim", function() require("telescope").load_extension("file_browser") end)
      end,
    },
    {
      "debugloop/telescope-undo.nvim",
      event = "VeryLazy",
      config = function()
        Util.on_load("telescope.nvim", function() require("telescope").load_extension("undo") end)
      end,
    },
  },
  keys = {
    { "<leader><space>", string.format("<cmd>%s<cr>", commands.telescope.file_browser), desc = "File Browser" },
    { "<leader>su", string.format("<cmd>%s<cr>", commands.telescope.undo), desc = "Undo Tree" },
  },
  opts = {
    defaults = {
      -- Content
      -- path_display = { "smart" },
      dynamic_preview_title = true,

      --- Layout
      layout_strategy = "flex",
      layout_config = {
        width = 0.90,
        height = 0.90,
        flex = {
          flip_columns = 140,
        },
      },
      -- winblend = 5,
      wrap_results = true,
    },
    pickers = {
      buffers = {
        sort_mru = true,
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      oldfiles = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      projects = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      find_files = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
        hidden = "true",
      },
      git_files = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      reloader = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      -- man_pages = { sections = { "2", "3" } },
      -- lsp_references = { path_display = { "shorten" } },
      lsp_document_symbols = { path_display = { "hidden" } },
      lsp_workspace_symbols = { path_display = { "shorten" } },
      -- lsp_code_actions = {},
      -- current_buffer_fuzzy_find = {},
      -- grep_string = {
      --   additional_args = {},
      -- },
      -- live_grep = {
      --   additional_args = {},
      -- },
    },
    extensions = {
      file_browser = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
        auto_depth = true,
        collapse_dirs = true,
        cwd_to_path = true,
        grouped = true,
        hidden = true,
        hide_parent_dir = true,
        hijack_netrw = true,
        prompt_path = true,
        -- respect_gitignore = false,
        select_buffer = true,
      },
      undo = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
      yank_history = {
        theme = "ivy",
        layout_config = {
          prompt_position = "bottom",
        },
      },
    },
  },
}
