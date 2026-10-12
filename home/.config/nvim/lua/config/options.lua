-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Cursor
vim.opt.guicursor = {
  --- Shape
  "i-c-ci:ver50",
  "n-v-sm:block",
  "o-r-cr:hor50",

  --- Blink rate
  "n-v-r-cr-c-ci-sm:blinkwait175-blinkoff150-blinkon175",
  "i:blinkwait700-blinkoff400-blinkon250",

  --- Highlights
  "c-ci-o:MCursorCommand/lCursorCommand",
  "i:MCursorInsert/lCursorInsert",
  "n:MCursorNormal/lCursorNormal",
  "r-cr:MCursorReplace/lCursorReplace",
  "v:MCursorVisual/lCursorVisual",
}

-- Numbers column
vim.opt.numberwidth = 6

-- don't hide stuff from me
vim.opt.conceallevel = 0

-- soft wrap
-- vim.o.showbreak = "╰╴"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakat:append("_")
vim.opt.breakindent = true
vim.opt.breakindentopt:append({
  "shift:2",
  -- "sbr", -- Display the 'showbreak' value before applying the additional indent.
})
-- vim.opt.cpoptions:append("n")

-- keep splits equal
vim.opt.equalalways = true

-- lines to keep at top / bottom
vim.opt.scrolloff = 16

-- python
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"

-- disable autoclosing brackets, quotes, etc.?
vim.g.minipairs_disable = true

-- additional filetypes
vim.filetype.add({
  filename = {
    Brewfile = "ruby",
  },
})

-- Use latest blink.cmp
vim.g.lazyvim_blink_main = true

-- Enable AI autocompletion
vim.g.ai_cmp = true

-- Default picker
vim.g.lazyvim_picker = "snacks"

-- Use prettier only when .prettierrc is found in project
vim.g.lazyvim_prettier_needs_config = true

-- Backup files to standard dir, see `:h backup`
vim.opt.backup = true
vim.opt.backupdir = vim.fn.stdpath("state") .. "/backup"

-- Disable spell check by default
vim.opt.spell = false

-- Are we using Ghostty?
vim.g.is_term_ghostty = vim.env["TERM"] == "xterm-ghostty"

-- Ghostty terminal support
if vim.g.is_term_ghostty then
  -- Add Ghostty plugins to the runtime path
  vim.opt.runtimepath:append(",/Applications/Ghostty.app/Contents/Resources/nvim/site/")
end
