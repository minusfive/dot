---@module 'obsidian'
---@module 'snacks'
---@module "which-key"

local date_format = "%Y-%m-%d"
local time_format = "%H:%M:%S"
local time_format_for_path = "%H-%M-%S" -- Used for file names to avoid colons.
local day_format = "%A"
local section_separator = " - "

local vaults = {
  { name = "Personal", path = "~/dev/personal/notes/Personal" },
  { name = "Work", path = "~/dev/work/notes/Work" },
}

-- Generates Obsidian workspaces after checking whether paths exist
---@return obsidian.workspace.WorkspaceSpec[]
local function get_obsidian_workspaces()
  local workspaces = {}
  for _, vault in ipairs(vaults) do
    if vim.fn.isdirectory(vault.path) then table.insert(workspaces, vault) end
  end
  return workspaces
end

local workspaces = get_obsidian_workspaces()

-- Cleans up the title by removing unwanted characters.
local clean_title = function(title)
  return title:gsub("'", ""):gsub("%W", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Returns formatted date and time. If no time is given, it defaults to the current time.
---@param time integer|?
---@return string
local get_timestamp_for_path = function(time)
  -- Returns the current date and time in the format YYYY-MM-DD - HH-MM-SS.
  return tostring(os.date(date_format .. section_separator .. time_format_for_path, time))
end

-- Prepends timestamp and cleans up title
---@param title string|?
---@return string
local get_note_id = function(title)
  local id = ""

  if title ~= nil then
    -- If title is given, clean it and replace whitespace with dashes.
    id = id .. clean_title(title):gsub("%W", "-")
  else
    -- If title is nil, just add 4 random uppercase letters to the suffix.
    for _ = 1, 4 do
      id = id .. string.char(math.random(65, 90))
    end
  end

  -- Prefix new title with the current date and time.
  return get_timestamp_for_path() .. section_separator .. id
end

-- Uses the title (cleaned up), or id if title is not found
---@param spec { id: string, dir: obsidian.Path, title: string|? }
---@return string|obsidian.Path path The full path to the new note.
local get_note_path = function(spec)
  local path = ""
  if spec.title then
    path = clean_title(spec.title)
  else
    path = tostring(spec.id)
  end
  path = spec.dir / path
  return path:with_suffix(".md")
end

---@param note obsidian.Note
---@return table
local get_note_frontmatter = function(note)
  -- Add the title of the note as an alias.
  if note.title then note:add_alias(note.title) end

  -- Remove `id` from default
  local out = { aliases = note.aliases, tags = note.tags }

  -- `note.metadata` contains any manually added fields in the frontmatter.
  -- So here we just make sure those fields are kept in the frontmatter.
  if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
    for k, v in pairs(note.metadata) do
      out[k] = v
    end
  end

  return out
end

-- Checks if we are currently in a vault.
---@return boolean
local is_in_vault = require("snacks.util").throttle(function()
  if not (Obsidian and Obsidian.workspace) then return false end
  return Obsidian.workspace.path:exists()
end, { ms = 100 })

-- Checks if the current file is an Obsidian note.
---@return boolean
local is_note = require("snacks.util").throttle(function()
  local api = require("obsidian.api")
  local bufPath = vim.api.nvim_buf_get_name(0)
  if #bufPath < 1 or not api then return false end
  return api.path_is_note(vim.api.nvim_buf_get_name(0), Obsidian.workspace)
end, { ms = 100 })

--- Only enable these keymaps for markdown files in a vault
vim.api.nvim_create_autocmd({ "LspAttach" }, {
  pattern = "*",
  callback = function()
    local _is_in_vault = is_in_vault()
    local _is_note = is_note()
    require("which-key").add({
      {
        "<leader>ob",
        "<cmd>Obsidian backlinks<cr>",
        desc = "Backlinks",
        icon = { icon = "󰌹 ", color = "purple" },
      },
      {
        "<leader>od",
        group = "Daily",
        mode = { "n", "v" },
        icon = { icon = "󰸗 ", color = "purple" },
        cond = _is_in_vault,
        {
          "<leader>odt",
          "<cmd>Obsidian today<cr>",
          desc = "Today",
          icon = { icon = "󰧓 ", color = "purple" },
        },
        {
          "<leader>odT",
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
        icon = { icon = "󱙓 ", color = "purple" },
        cond = _is_in_vault,
      },
      {
        "<leader>ol",
        "<ESC><cmd>'<,'>Obsidian link<cr>",
        desc = "Link",
        mode = { "v" },
        icon = { icon = "󰌹 ", color = "purple" },
        cond = _is_note,
      },
      {
        "<leader>on",
        group = "New",
        mode = { "n", "v" },
        icon = { icon = "󰎜 ", color = "purple" },
        cond = _is_in_vault,
        {
          "<leader>one",
          "<ESC><cmd>'<,'>Obsidian extract_note<cr>",
          desc = "Extract Selection",
          mode = { "v" },
          icon = { icon = "󰚸 ", color = "purple" },
          cond = _is_note,
        },
        {
          "<leader>onl",
          "<ESC><cmd>'<,'>Obsidian link_new<cr>",
          desc = "Link",
          mode = { "v" },
          icon = { icon = "󱄀 ", color = "purple" },
          cond = _is_note,
        },
        {
          "<leader>onn",
          "<cmd>Obsidian new<cr>",
          desc = "Note",
          icon = { icon = "󰎜 ", color = "purple" },
        },
        {
          "<leader>ont",
          "<cmd>Obsidian new_from_template<cr>",
          desc = "Note from Template",
          icon = { icon = "󰚹 ", color = "purple" },
        },
      },
      {
        "<leader>oo",
        "<cmd>Obsidian open<cr>",
        desc = "Open in Obsidian",
        icon = { icon = "󰏋 ", color = "purple" },
        cond = _is_note,
      },
      {
        "<leader>or",
        "<cmd>Obsidian rename<cr>",
        desc = "Rename",
        icon = { icon = "󰑕 ", color = "purple" },
        cond = _is_note,
      },
      {
        "<leader>os",
        "<cmd>Obsidian search<cr>",
        desc = "Search Text",
        icon = { icon = "󱩾 ", color = "purple" },
        cond = _is_in_vault,
      },
      {
        "<leader>ot",
        "<cmd>Obsidian template<cr>",
        desc = "Template Picker",
        icon = { icon = "󱙔 ", color = "purple" },
        buffer = true,
        cond = _is_note,
      },
    })
  end,
})

return {
  {
    "obsidian-nvim/obsidian.nvim",
    -- dev = true,
    -- version = "*", -- Recommended, use latest release instead of latest commit
    -- optional = true,
    lazy = true,

    -- Enable only for markdown files, or (see lines below)...
    -- ft = "markdown",

    -- ...only load for markdown files in vault:
    -- event = {
    --   -- if you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "bufreadpre " .. vim.fn.expand "~" .. "/my-vault/**.md"
    --   "bufreadpre "
    --     .. vaults_dir
    --     .. "**/**.md",
    --   "bufnewfile " .. vaults_dir .. "**/**.md",
    -- },

    dependencies = {
      -- required.
      "nvim-lua/plenary.nvim",
    },

    ---@type obsidian.config
    opts = {
      -- either 'wiki' or 'markdown'.
      preferred_link_style = "markdown",

      -- optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
      completion = {
        blink = true,
        nvim_cmp = false,
      },

      picker = {
        name = "snacks.pick",
      },

      footer = {
        enabled = false, -- turn it off
        -- separator = true, -- turn it off
        separator = "", -- insert a blank line
        format = "words: {{words}}  ch: {{chars}}  props: {{properties}}  backlinks: {{backlinks}}",
        -- format = "({{backlinks}} backlinks)", -- limit to backlinks
        -- hl_group = "@property", -- Use another hl group
      },

      -- a list of workspace names, paths, and configuration overrides.
      -- if you use the obsidian app, the 'path' of a workspace should generally be
      -- your vault root (where the `.obsidian` folder is located).
      -- when obsidian.nvim is loaded by your plugin manager, it will automatically set
      -- the workspace to the first workspace in the list whose `path` is a parent of the
      -- current markdown file being edited.
      workspaces = workspaces,

      daily_notes = {
        -- optional, if you keep daily notes in a separate directory.
        folder = nil,
        -- optional, if you want to change the date format for the id of daily notes.
        date_format = date_format .. " - " .. day_format,
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
      templates = {
        folder = "Templates",
        date_format = date_format,
        time_format = time_format,
        -- a map for custom variables, the key should be the variable and the value a function
        substitutions = {
          ["date:dddd"] = function() return tostring(os.date(day_format)) end,
        },
      },

      -- optional, configure additional syntax highlighting / extmarks.
      -- this requires you have `conceallevel` set to 1 or 2. see `:help conceallevel` for more details.
      ui = {
        -- Disabled so it doesn't conflict with `render-markdown.nvim`.
        enable = false, -- set to false to disable all additional syntax features
      },

      -- customize how note ids are generated given an optional title.
      note_id_func = get_note_id,

      -- customize how note file names are generated given the ID, target directory, and title.
      note_path_func = get_note_path,

      -- customize how the frontmatter of a note is generated.
      note_frontmatter_func = get_note_frontmatter,

      callbacks = {
        -- Automatically switch to the correct workspace based on the current working directory.
        post_setup = function()
          local cwd = vim.fn.getcwd()
          for _, ws in pairs(Obsidian.opts.workspaces) do
            local dev_path = "/dev/" .. ws.name:lower()
            if (Obsidian.workspace.name ~= ws.name) and string.find(cwd, dev_path) then
              Obsidian.workspace.set(ws.name)
            end
          end
        end,
      },

      -- Specify how to handle attachments.
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

    ---@type snacks.Config
    opts = {
      picker = {
        actions = {
          obsidian_find_or_create_note = function(picker)
            if is_in_vault() and #picker:items() == 0 then
              -- If no items are selected, create a new note.
              local ObsidianNote = require("obsidian.note")
              local note = ObsidianNote.create({ title = picker.input:get() })
              ObsidianNote.open(note)
            else
              picker:action("confirm")
            end
          end,
        },

        sources = {
          grep = {
            need_search = false,
            exclude = { ".obsidian" },
            win = {
              input = {
                keys = {
                  ["<c-o>"] = { "obsidian_find_or_create_note", desc = "New Note", mode = { "n", "i", "v" } },
                },
              },
            },
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
    ---@type wk.Config|{}
    opts = {
      -- Add Obsidian specific keybindings to the which-key menu.
      spec = {
        {
          "<leader>o",
          group = "Obsidian",
          mode = { "n", "v" },
          icon = { icon = "󱞁 ", color = "purple" },
          cond = function() return LazyVim.has("obsidian.nvim") end,
          {
            "<leader>ow",
            "<cmd>Obsidian workspace<cr>",
            desc = "Workspace Picker",
            icon = { icon = " ", color = "purple" },
          },
        },
      },
    },
  },
}
