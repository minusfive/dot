---@module "csvview"
---@module 'lazy'
---@module 'snacks'

---@type LazySpec
return {
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    ---@param opts CsvView.Options
    opts = function(_, opts)
      ---@type CsvView.Options
      local new_opts = {
        parser = { comments = { "#", "//" } },
        keymaps = {
          -- Text objects for selecting fields
          textobject_field_inner = { "if", mode = { "o", "x" } },
          textobject_field_outer = { "af", mode = { "o", "x" } },
          -- Excel-like navigation:
          -- Use <Tab> and <S-Tab> to move horizontally between fields.
          -- Use <Enter> and <S-Enter> to move vertically between rows and place the cursor at the end of the field.
          -- Note: In terminals, you may need to enable CSI-u mode to use <S-Tab> and <S-Enter>.
          jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
          jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
          jump_next_row = { "<Enter>", mode = { "n", "v" } },
          jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
        },
        view = {
          display_mode = "border",
        },
      }

      require("lazy.util").merge(opts, new_opts)

      Snacks.toggle({
        name = "Table View",
        get = function() return require("csvview").is_enabled(0) end,
        set = function() require("csvview").toggle() end,
      }):map("<leader>ut")
    end,
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  },
}
