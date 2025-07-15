local common_settings = {
  preferGoToSourceDefinition = true,
  preferences = {
    importModuleSpecifier = "non-relative",
    preferGoToSourceDefinition = true,
  },
}

local vue_ls_config = {
  mason = false,
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { "vue" },
  root_markers = { "package.json" },
  on_init = function(client)
    client.handlers["tsserver/request"] = function(_, result, context)
      local clients = vim.lsp.get_clients({ bufnr = context.bufnr, name = "vtsls" })
      if #clients == 0 then
        vim.notify("Could not found `vtsls` lsp client, vue_lsp would not work without it.", vim.log.levels.ERROR)
        return
      end
      local ts_client = clients[1]

      local param = unpack(result)
      local id, command, payload = unpack(param)
      ts_client:exec_cmd({
        title = "vue_request_forward", -- You can give title anything as it's used to represent a command in the UI, `:h Client:exec_cmd`
        command = "typescript.tsserverRequest",
        arguments = {
          command,
          payload,
        },
      }, { bufnr = context.bufnr }, function(_, r)
        local response_data = r and { { id, r.body } } or { { id } }
        client:notify("tsserver/response", response_data)
      end)
    end
  end,
}

return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@module 'lspconfig'
      ---@type {[string]: lspconfig.Config|{}}
      servers = {
        vtsls = {
          root_markers = { ".git" },
          settings = {
            javascript = common_settings,
            typescript = common_settings,
          },
        },
        volar = {
          enabled = false,
        },
        vuels = vue_ls_config,
      },
    },
  },

  { "dmmulroy/ts-error-translator.nvim" },
}
