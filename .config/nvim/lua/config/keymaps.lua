-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Wrapper around vim.keymap.set that prevents keymaps from being set if a lazy key handler is active
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts vim.keymap.set.Opts|?
local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    if opts.remap and not vim.g.vscode then opts.remap = nil end
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Delete problematic keymaps
vim.keymap.del("n", "<leader>L")
vim.keymap.del("n", "<leader>l")

-- Save all files with `󰘳  + s`
map({ "i", "x", "n", "s" }, "<D-s>", "<cmd>wall<cr><esc>", { desc = "Save All Files" })

-- Move to window using <ctrl>w + arrow keys. Which-key also remaps these to <leader>w + arrow keys
map("n", "<C-w><Left>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-w><Down>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<C-w><Up>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<C-w><Right>", "<C-w>l", { desc = "Go to Right Window", remap = true })
