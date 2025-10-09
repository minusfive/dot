local common_settings = {
  -- preferGoToSourceDefinition = true,
  preferences = {
    -- importModuleSpecifier = "non-relative",
    importModuleSpecifierEnding = "auto",
    includePackageJsonAutoImports = "on",
    -- preferGoToSourceDefinition = true,
  },
  -- updateImportsOnFileMove = { enabled = "always" },
  -- suggest = {
  --   completeFunctionCalls = true,
  -- },
  -- inlayHints = {
  --   enumMemberValues = { enabled = true },
  --   functionLikeReturnTypes = { enabled = true },
  --   parameterNames = { enabled = "literals" },
  --   parameterTypes = { enabled = true },
  --   propertyDeclarationTypes = { enabled = true },
  --   variableTypes = { enabled = false },
  -- },
}

---@type LazySpec
return {
  { "dmmulroy/ts-error-translator.nvim" },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          settings = {
            typescript = common_settings,
            javascript = common_settings,
          },
        },
      },
    },
  },
}
