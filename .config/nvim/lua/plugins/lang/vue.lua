---@module 'lazy'
---@module 'mason'

---@type LazySpec
return {
  {
    "mason-org/mason.nvim",

    ---@type MasonSettings
    opts = {
      registries = { "file:" .. vim.fn.stdpath("config") .. "/lua/mason-registry", "github:mason-org/mason-registry" },
    },
  },
}
