-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- mouse
-- vim.opt.mousemoveevent = true

-- blinking cursor
vim.opt.guicursor = {
  "n-v-r-cr:block-blinkwait175-blinkoff150-blinkon175",
  "i-c-ci-ve:ver50",
  "r-cr:MCursorReplace/lMCursorReplace",
  "o:hor50-MCursorCommand/lMCursorCommand",
  "c-ci:MCursorCommand/lMCursorCommand",
  "i:blinkwait700-blinkoff400-blinkon250-MCursorInsert/lMCursorInsert",
  "n:MCursorNormal/lMCursorNormal",
  "v:MCursorVisual/lMCursorVisual",
  "sm:block-blinkwait175-blinkoff150-blinkon175",
}

-- don't hide stuff from me
vim.opt.conceallevel = 0

-- soft wrap
-- vim.o.showbreak = "╰╴"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakat:append("_")
vim.opt.breakindent = true
vim.opt.breakindentopt:append({
  "shift:3",
  -- "sbr", -- Display the 'showbreak' value before applying the additional indent.
})
-- vim.opt.cpoptions:append("n")

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
-- vim.g.lazyvim_blink_main = true

-- Use global mise tools, skipping local
local _tools = { "node", "lua", "luarocks", "ruby", "python" }
for _, _t in ipairs(_tools) do
  vim.env.PATH = vim.env.HOME .. "/.local/share/mise/installs/" .. _t .. "/latest/bin:" .. vim.env.PATH
end
