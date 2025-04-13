---Generates indexed keymaps from 1 to 0 (0 being the 10th index)
---@param idx number
local function get_keymap_for_idx(idx)
  -- Only show for the first 10 items
  if idx > 10 then return end
  return "A-" .. (idx % 10)
end

---Generates the indexed keymap hint text
---@param ctx blink.cmp.DrawItemContext
local function keymap_index_text(ctx) return get_keymap_for_idx(ctx.idx) end

---Generates a keymap with indexed `accept` actions from 1 to 0 (0 being the 10th index)
local indexed_keymap = (function()
  ---@type blink.cmp.KeymapConfig
  local keymap = { preset = "super-tab", ["<C-S-y>"] = { "select_and_accept" } }

  for i = 1, 10 do
    local idx_map = get_keymap_for_idx(i)
    if not idx_map then break end
    keymap["<" .. idx_map .. ">"] = { function(cmp) cmp.accept({ index = i }) end }
  end

  return keymap
end)()

return {
  -- Copilot Broken: https://github.com/zbirenbaum/copilot.lua/issues/408#issuecomment-2758411881
  -- { "zbirenbaum/copilot.lua", commit = "99654fe9ad6cb2500c66b178a03326f75c95f176" },

  {
    "saghen/blink.cmp",
    optional = true,
    -- dev = true,

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      fuzzy = { implementation = "prefer_rust_with_warning" },

      completion = {
        accept = { auto_brackets = { enabled = false } },
        menu = {
          draw = {
            align_to = "label",
            treesitter = { "lsp" },
            columns = {
              { "item_idx" },
              { "label", "label_description", gap = 1 },
              { "kind_icon", "source_name", gap = 1 },
            },
            components = {
              -- Add indexed selection keymaps hints
              item_idx = {
                text = keymap_index_text,
                highlight = "BlinkCmpItemIdx",
              },

              -- Add syntax highlighting for the label
              label = {
                text = function(ctx) return require("colorful-menu").blink_components_text(ctx) end,
                highlight = function(ctx) return require("colorful-menu").blink_components_highlight(ctx) end,
              },
            },
          },
        },
      },

      keymap = indexed_keymap,

      -- signature = { enabled = true },

      -- TODO: Explore other ways of reverting overrides?
      -- Force enable commandline completion
      cmdline = vim.tbl_deep_extend("force", {}, require("blink.cmp.config").cmdline, {
        keymap = indexed_keymap,
        completion = {
          menu = { auto_show = true },
          ghost_text = { enabled = true },
        },
      }),

      sources = {
        providers = {
          copilot = {
            score_offset = 0,
          },
        },
      },
    },
  },

  --- Syntax highlighting for completion menu
  {
    "xzbdmw/colorful-menu.nvim",
    config = function()
      -- You don't need to set these options.
      require("colorful-menu").setup({
        ls = {
          lua_ls = {
            -- Maybe you want to dim arguments a bit.
            arguments_hl = "@comment",
          },
          gopls = {
            -- By default, we render variable/function's type in the right most side,
            -- to make them not to crowd together with the original label.

            -- when true:
            -- foo             *Foo
            -- ast         "go/ast"

            -- when false:
            -- foo *Foo
            -- ast "go/ast"
            align_type_to_right = true,
            -- When true, label for field and variable will format like "foo: Foo"
            -- instead of go's original syntax "foo Foo". If align_type_to_right is
            -- true, this option has no effect.
            add_colon_before_type = false,
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
          },
          -- for lsp_config or typescript-tools
          ts_ls = {
            -- false means do not include any extra info,
            -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
            extra_info_hl = "@comment",
          },
          vtsls = {
            -- false means do not include any extra info,
            -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
            extra_info_hl = "@comment",
          },
          ["rust-analyzer"] = {
            -- Such as (as Iterator), (use std::io).
            extra_info_hl = "@comment",
            -- Similar to the same setting of gopls.
            align_type_to_right = true,
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
          },
          clangd = {
            -- Such as "From <stdio.h>".
            extra_info_hl = "@comment",
            -- Similar to the same setting of gopls.
            align_type_to_right = true,
            -- the hl group of leading dot of "•std::filesystem::permissions(..)"
            import_dot_hl = "@comment",
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
          },
          zls = {
            -- Similar to the same setting of gopls.
            align_type_to_right = true,
          },
          roslyn = {
            extra_info_hl = "@comment",
          },
          dartls = {
            extra_info_hl = "@comment",
          },
          -- The same applies to pyright/pylance
          basedpyright = {
            -- It is usually import path such as "os"
            extra_info_hl = "@comment",
          },
          -- If true, try to highlight "not supported" languages.
          fallback = true,
          -- this will be applied to label description for unsupport languages
          fallback_extra_info_hl = "@comment",
        },
        -- If the built-in logic fails to find a suitable highlight group for a label,
        -- this highlight is applied to the label.
        fallback_highlight = "@variable",
        -- If provided, the plugin truncates the final displayed text to
        -- this width (measured in display cells). Any highlights that extend
        -- beyond the truncation point are ignored. When set to a float
        -- between 0 and 1, it'll be treated as percentage of the width of
        -- the window: math.floor(max_width * vim.api.nvim_win_get_width(0))
        -- Default 60.
        max_width = 60,
      })
    end,
  },
}
