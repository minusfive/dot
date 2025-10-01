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
        vue_ls = { mason = false },
        vtsls = {
          settings = {
            typescript = common_settings,
            javascript = common_settings,
          },
        },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Override tsserver plugin location to use mise npm installation
      if
        opts.servers
        and opts.servers.vtsls
        and opts.servers.vtsls.settings
        and opts.servers.vtsls.settings.vtsls
        and opts.servers.vtsls.settings.vtsls.tsserver
        and opts.servers.vtsls.settings.vtsls.tsserver.globalPlugins
      then
        for _, plugin in ipairs(opts.servers.vtsls.settings.vtsls.tsserver.globalPlugins) do
          if plugin.name ~= "@vue/typescript-plugin" then return end
          if plugin.location then
            plugin.location = vim.env.HOME .. "/.local/share/mise/installs/npm-vue-language-server/latest"
          end
        end
      end
    end,
  },
}
