---@module 'copilot'

---@type LazySpec
return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,

    ---@type CopilotConfig|{}
    opts = {
      server = {
        type = "binary",
      },
    },
  },
}
