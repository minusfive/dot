local vaults = { personal = "Personal", work = "Work" }
local vaults_dir = vim.fn.expand("~/Notes/")
local date_format = "%Y-%m-%d"
local time_format = "%H-%M-%S"
local day_format = "%w"
local section_separator = "--"

---Replicates Obsidian's default unique note id generation.
---@param title string|?
---@return string
local title_id = function(title)
  -- Prefix new title with the current date and time.
  local new_title = tostring(os.date(date_format .. section_separator .. time_format)) .. section_separator

  if title ~= nil then
    -- If title is given, transform it into valid file name.
    new_title = new_title .. (title:gsub("%W", "-"))
  else
    -- If title is nil, just add 4 random uppercase letters to the suffix.
    for _ = 1, 4 do
      new_title = new_title .. string.char(math.random(65, 90))
    end
  end

  return new_title
end

return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    -- optional = true,
    lazy = true,

    -- Enable only for markdown files, or (see lines below)...
    -- ft = "markdown",

    -- ...only load for markdown files in vault:
    -- event = {
    --   -- if you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- e.g. "bufreadpre " .. vim.fn.expand "~" .. "/my-vault/**.md"
    --   "bufreadpre "
    --     .. vaults_dir
    --     .. "**/**.md",
    --   "bufnewfile " .. vaults_dir .. "**/**.md",
    -- },

    dependencies = {
      -- required.
      "nvim-lua/plenary.nvim",
    },
    keys = {},

    ---@module 'obsidian'
    ---@type obsidian.config.ClientOpts|{}
    opts = {
      -- either 'wiki' or 'markdown'.
      preferred_link_style = "markdown",

      -- optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
      ---@type obsidian.config.CompletionOpts|{}
      completion = {
        nvim_cmp = false,
        blink = true,
      },

      -- optional, set preferred picker
      ---@type obsidian.config.PickerOpts|{}
      picker = {
        name = "snacks.pick", -- or 'fzf' or 'builtin'
      },

      -- a list of workspace names, paths, and configuration overrides.
      -- if you use the obsidian app, the 'path' of a workspace should generally be
      -- your vault root (where the `.obsidian` folder is located).
      -- when obsidian.nvim is loaded by your plugin manager, it will automatically set
      -- the workspace to the first workspace in the list whose `path` is a parent of the
      -- current markdown file being edited.
      workspaces = {
        {
          name = vaults.personal,
          path = vaults_dir .. vaults.personal,
        },
        {
          name = vaults.work,
          path = vaults_dir .. vaults.work,
        },
      },

      ---@type obsidian.config.DailyNotesOpts|{}
      daily_notes = {
        -- optional, if you keep daily notes in a separate directory.
        folder = nil,
        -- optional, if you want to change the date format for the id of daily notes.
        date_format = date_format .. section_separator .. day_format,
        -- optional, if you want to change the date format of the default alias of daily notes.
        -- alias_format = "%b %-d, %y",
        -- optional, default tags to add to each new daily note created.
        default_tags = { "daily-notes" },
        -- optional, if you want to automatically insert a template from your template directory like 'daily.md'
        template = "Note.md",
        -- Optional, if you want `Obsidian yesterday` to return the last work day or `Obsidian tomorrow` to return the next work day.
        workdays_only = false,
      },
      -- optional, for templates (see below).
      ---@type obsidian.config.TemplateOpts|{}
      templates = {
        folder = "Templates",
        date_format = date_format,
        time_format = time_format,
        -- a map for custom variables, the key should be the variable and the value a function
        substitutions = {},
      },

      -- optional, configure additional syntax highlighting / extmarks.
      -- this requires you have `conceallevel` set to 1 or 2. see `:help conceallevel` for more details.
      ui = {
        enable = false, -- set to false to disable all additional syntax features
        update_debounce = 200, -- update delay after a text change (in milliseconds)
        max_file_length = 5000, -- disable ui features for files with more than this many lines
        -- define how various check-boxes are displayed
        ---@type table<string, obsidian.config.CheckboxSpec|{}>
        checkboxes = {
          -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
          [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
          ["x"] = { char = "", hl_group = "ObsidianDone" },
          [">"] = { char = "", hl_group = "ObsidianRightArrow" },
          ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
          ["!"] = { char = "", hl_group = "ObsidianImportant" },
          -- Replace the above with this if you don't have a patched font:
          -- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
          -- ["x"] = { char = "✔", hl_group = "ObsidianDone" },

          -- You can also add more custom ones...
        },
        -- Use bullet marks for non-checkbox lists.
        bullets = { char = "•", hl_group = "ObsidianBullet" },
        external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
        -- Replace the above with this if you don't have a patched font:
        -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
        reference_text = { hl_group = "ObsidianRefText" },
        highlight_text = { hl_group = "ObsidianHighlightText" },
        tags = { hl_group = "ObsidianTag" },
        block_ids = { hl_group = "ObsidianBlockID" },
        -- hl_groups = {
        --   -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
        --   ObsidianTodo = { bold = true, fg = "#f78c6c" },
        --   ObsidianDone = { bold = true, fg = "#89ddff" },
        --   ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
        --   ObsidianTilde = { bold = true, fg = "#ff5370" },
        --   ObsidianImportant = { bold = true, fg = "#d73128" },
        --   ObsidianBullet = { bold = true, fg = "#89ddff" },
        --   ObsidianRefText = { underline = true, fg = "#c792ea" },
        --   ObsidianExtLinkIcon = { fg = "#c792ea" },
        --   ObsidianTag = { italic = true, fg = "#89ddff" },
        --   ObsidianBlockID = { italic = true, fg = "#89ddff" },
        --   ObsidianHighlightText = { bg = "#75662e" },
        -- },
      },

      -- optional, customize how note ids are generated given an optional title.
      note_id_func = title_id,

      -- Specify how to handle attachments.
      ---@type obsidian.config.AttachmentsOpts|{}
      attachments = {
        -- The default folder to place images in via `:ObsidianPasteImg`.
        -- If this is a relative path it will be interpreted as relative to the vault root.
        -- You can always override this per image by passing a full path to the command instead of just a filename.
        img_folder = "Assets", -- This is the default
        -- A function that determines the text to insert in the note when pasting an image.
        -- It takes two arguments, the `obsidian.Client` and an `obsidian.Path` to the image file.
        -- This is the default implementation.
        -- ---@param client obsidian.Client
        -- ---@param path obsidian.Path the absolute path to the image file
        -- ---@return string
        -- img_text_func = function(client, path)
        --   path = client:vault_relative_path(path) or path
        --   return string.format("![%s](%s)", path.name, path)
        -- end,
      },
    },
  },

  {
    "folke/snacks.nvim",
    optional = true,
    opts = {
      ---@type snacks.picker.Config
      picker = {
        sources = {
          grep = {
            need_search = false,
            exclude = { ".obsidian" },
          },
          files = {
            exclude = { ".obsidian" },
          },
        },
      },
    },
  },

  {
    "folke/which-key.nvim",
    ---@module "which-key"
    ---@type wk.Config|{}
    opts = {
      -- Add Obsidian specific keybindings to the which-key menu.
      spec = {
        {
          "<leader>o",
          group = "Obsidian",
          mode = { "n", "v" },
          icon = { icon = "󱇧 ", color = "purple" },
          cond = function() return LazyVim.has("obsidian.nvim") end,
          {
            "<leader>od",
            group = "Daily",
            mode = { "n", "v" },
            icon = { icon = "󰸗 ", color = "purple" },
            {
              "<leader>odd",
              "<cmd>Obsidian today<cr>",
              desc = "Today",
              icon = { icon = "󰧓 ", color = "purple" },
            },
            {
              "<leader>odt",
              "<cmd>Obsidian tomorrow<cr>",
              desc = "Tomorrow",
              icon = { icon = "󱄵 ", color = "purple" },
            },
            {
              "<leader>ody",
              "<cmd>Obsidian yesterday<cr>",
              desc = "Yesterday",
              icon = { icon = "󱄴 ", color = "purple" },
            },
          },
          {
            "<leader>of",
            "<cmd>Obsidian quick_switch<cr>",
            desc = "Find Note",
            icon = { icon = "󰱼 ", color = "purple" },
          },
          {
            "<leader>ol",
            "<ESC><cmd>'<,'>Obsidian link<cr>",
            desc = "Link Picker",
            mode = { "v" },
            cond = function() require("obsidian").get_client():vault_name() end,
            icon = { icon = "󱅷 ", color = "purple" },
          },
          {
            "<leader>on",
            "<cmd>Obsidian new<cr>",
            desc = "New Note",
            icon = { icon = "󰝒 ", color = "purple" },
          },
          {
            "<leader>oN",
            "<cmd>Obsidian new_from_template<cr>",
            desc = "New Note from Template",
            icon = { icon = "󱪝 ", color = "purple" },
          },
          {
            "<leader>oo",
            "<cmd>Obsidian open<cr>",
            desc = "Open in Obsidian",
            icon = { icon = "󰏋 ", color = "purple" },
          },
          {
            "<leader>os",
            "<cmd>Obsidian search<cr>",
            desc = "Search Text",
            icon = { icon = "󰱽 ", color = "purple" },
          },
          {
            "<leader>ot",
            "<cmd>Obsidian template<cr>",
            desc = "Template Picker",
            icon = { icon = "󰱽 ", color = "purple" },
          },
          {
            "<leader>ow",
            group = "Workspace",
            desc = "Workspace Picker",
            icon = { icon = "󰴕 ", color = "purple" },
            {
              "<leader>owf",
              "<cmd>Obsidian workspace<cr>",
              desc = "Find",
              icon = { icon = "󰴕 ", color = "purple" },
            },
            {
              "<leader>owp",
              "<cmd>Obsidian workspace Personal<cr>",
              desc = "Personal",
              icon = { icon = "󰋜 ", color = "purple" },
            },
            {
              "<leader>oww",
              "<cmd>Obsidian workspace Work<cr>",
              desc = "Work",
              icon = { icon = "󰦑 ", color = "purple" },
            },
          },
        },
      },
    },
  },
}
