---@class MinusfiveUtils
local MinusfiveUtils = {}

---Retrieves an LSP client by name
---@param name string
---@return vim.lsp.Client[]
function MinusfiveUtils.getLSPClientsByName(name) return vim.lsp.get_clients({ bufnr = 0, name = name }) end

---Toggles an LSP client by name
---@param name string
---@return nil
function MinusfiveUtils.toggleLSPClient(name)
  local clients = MinusfiveUtils.getLSPClientsByName(name)
  if #clients > 0 then
    for _, client in ipairs(clients) do
      client:stop(true)
    end
  else
    vim.cmd("LspStart " .. name)
  end
end

--- Check if current working directory is a descendant of a given directory
---@param ancestor_dir string
function MinusfiveUtils.cwd_is_descendant_of_dir(ancestor_dir) return vim.fn.getcwd():find(ancestor_dir, 1, true) ~= nil end

return MinusfiveUtils
