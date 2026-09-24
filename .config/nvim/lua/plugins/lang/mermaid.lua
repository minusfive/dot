---@module 'conform'

local function mermaid_plugin_path()
  local mermaidfmt = vim.fn.exepath("mermaidfmt")
  if mermaidfmt == "" then return "mermaid-formatter/prettier-plugin" end

  return vim.fs.joinpath(vim.fs.dirname(vim.fn.resolve(mermaidfmt)), "prettier-plugin.js")
end

---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    optional = true,
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {
        mermaid = { "prettier_mermaid" },
      },
      formatters = {
        prettier_mermaid = {
          inherit = "prettier",
          prepend_args = function() return { "--plugin", mermaid_plugin_path() } end,
        },
      },
    },
  },
}
