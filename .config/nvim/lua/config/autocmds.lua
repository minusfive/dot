-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local buftypes_non_file = { "terminal", "quickfix", "nofile", "prompt", "help" }

---@param ev vim.api.create_autocmd.callback.args
---@return boolean
local function is_non_file_buffer(ev) return vim.list_contains(buftypes_non_file, vim.bo[ev.buf].buftype) end

---@param name string
local function augroup(name) return vim.api.nvim_create_augroup("minusfive_" .. name, { clear = true }) end

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  desc = "Use relative numbers",
  group = augroup("relative_numbers"),
  callback = function(ev)
    if is_non_file_buffer(ev) then return end

    vim.wo.relativenumber = true
  end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  desc = "Use absolute numbers",
  group = augroup("absolute_numbers"),
  callback = function(ev)
    if is_non_file_buffer(ev) then return end

    vim.wo.relativenumber = false
  end,
})

-- Disable diagnostics on .env files
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { "*.env", "*.env.*" },
  desc = "Disable diagnostics on .env files",
  group = augroup("disable_diagnostics_on_env"),
  callback = function(ev)
    if vim.bo.filetype == "sh" then vim.diagnostic.enable(false, { bufnr = ev.buf }) end
  end,
})

-- Disable LazyVim's wrap_spell autocmd that enables spell checking for text filetypes
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
