local common_settings = {
  -- preferGoToSourceDefinition = true,
  preferences = {
    importModuleSpecifier = "non-relative",
    -- preferGoToSourceDefinition = true,
  },
  updateImportsOnFileMove = { enabled = "always" },
  suggest = {
    completeFunctionCalls = true,
  },
  inlayHints = {
    enumMemberValues = { enabled = true },
    functionLikeReturnTypes = { enabled = true },
    parameterNames = { enabled = "literals" },
    parameterTypes = { enabled = true },
    propertyDeclarationTypes = { enabled = true },
    variableTypes = { enabled = false },
  },
}

local vue_plugin = {
  name = "@vue/typescript-plugin",
  location = vim.env.HOME
    .. "/.local/share/mise/installs/node/latest/lib/node_modules/@vue/language-server/node_modules",
  languages = { "vue" },
  configNamespace = "typescript",
  enableForWorkspaceTypeScriptVersions = true,
}

vim.lsp.config("vtsls", {
  complete_function_calls = true,
  settings = {
    vtsls = {
      enableMoveToFileCodeAction = true,
      experimental = {
        completion = {
          -- enableServerSideFuzzyMatch = true,
        },
      },
      autoUseWorkspaceTsdk = true,
      javascript = common_settings,
      typescript = common_settings,
      tsserver = {
        globalPlugins = {
          vue_plugin,
        },
      },
    },
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue",
  },
})

--NOTE: Not necessary on current LSPConfig
-- vim.lsp.config("vue_ls", vue_ls_config)
vim.lsp.enable({ "vtsls", "vue_ls" })

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@module 'lspconfig'
      ---@type {[string]: lspconfig.Config|{}}
      servers = {
        vtsls = { enabled = false },
        volar = { enabled = false },
        vuels = { enabled = false },
      },
    },
  },

  { "dmmulroy/ts-error-translator.nvim" },
}
