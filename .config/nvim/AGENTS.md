# Neovim Configuration - AI Rules and Guidelines

Advanced Neovim configuration built on LazyVim with modern plugins and Lua-based development environment. Core technologies: LazyVim, lazy.nvim, Lua scripting, LSP integration, completion systems, AI assistance.

## READ FIRST: MANDATORY Rules and Guidelines

**You MUST follow everything stipulated on the [main AGENTS.md](../../AGENTS.md) file first and foremost**. That file **SUPERSEDES** any seemingly contradictory language found on this file or anywhere else.

If you detect any such contradictions, you **MUST** report them so they can be resolved.

## Neovim Configuration Overview

### Directory Structure

```sh
.config/nvim/               # Neovim configuration root
├── after/                  # After-directory for filetype-specific configs
│   ├── ftplugin/          # Filetype plugins
│   └── queries/           # Tree-sitter queries
├── lua/                   # Lua configuration modules
│   ├── config/            # Core configuration
│   │   ├── autocmds.lua   # Autocommands
│   │   ├── keymaps.lua    # Global keymaps
│   │   ├── lazy.lua       # Plugin manager setup
│   │   ├── logos.lua      # Dashboard logos
│   │   └── options.lua    # Vim options
│   └── plugins/           # Plugin configurations
│       ├── lang/          # Language-specific plugins
│       ├── ai.lua         # AI and completion tools
│       ├── completion.lua # Completion system
│       ├── editor.lua     # Editor enhancements
│       ├── theme.lua      # Theme and UI configuration
│       └── [others]       # Additional plugin configs
├── init.lua               # Neovim entry point
├── lazy-lock.json         # Plugin version lockfile
├── lazyvim.json          # LazyVim configuration
└── spell/                # Spell check dictionaries
```

### Architecture Overview

- **Plugin Manager**: lazy.nvim for modern plugin management with lazy loading
- **Base Framework**: LazyVim providing sensible defaults and plugin ecosystem
- **Completion Engine**: blink.cmp with LSP integration and AI assistance
- **AI Integration**: CodeCompanion with Copilot, VectorCode, and MCP Hub
- **Theme System**: Catppuccin with custom highlight overrides
- **Language Support**: Comprehensive LSP, Tree-sitter, and formatter integration
- **Development Tools**: Built-in debugger, testing, and refactoring support

### Core Knowledge Requirements and Technology Stack

- Lua programming language and Neovim Lua API
- LazyVim framework and plugin ecosystem
- LSP (Language Server Protocol) configuration and usage
- Tree-sitter for syntax highlighting and code analysis
- Plugin development with lazy.nvim specifications
- Completion systems and snippet engines
- AI-assisted development workflows
- Modern Neovim features (LSP, Tree-sitter, floating windows)

### Key Plugin Ecosystem

- **AI & Completion**: CodeCompanion, Copilot, blink.cmp, VectorCode
- **Editor**: Flash (motion), Trouble (diagnostics), Which-key (key bindings)
- **UI**: Catppuccin (theme), Snacks (utilities), Neo-tree (file explorer)
- **Language**: Mason (LSP management), Tree-sitter, various language servers
- **Development**: DAP (debugging), Test runners, Refactoring tools

## Neovim-Specific Coding Guidelines

### Keymap Management with Which-Key

```lua
-- filepath: .config/nvim/lua/plugins/example.lua
return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>x", group = "Custom Group", icon = "󰊢" },
        { "<leader>xa", "<cmd>CustomAction<cr>", desc = "Custom Action" },
      },
    },
  },
}
```

#### Programmatic Which-Key Registration

```lua
-- filepath: .config/nvim/lua/config/autocmds.lua
-- Dynamic keymaps based on filetype using which-key
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = "lua",
  callback = function()
    local wk = require("which-key")
    wk.add({
      { "<leader>lr", "<cmd>source %<cr>", desc = "Reload Lua file", buffer = true },
      { "<leader>lf", group = "Lua Functions", buffer = true },
      { "<leader>lft", "<cmd>lua print('Test')<cr>", desc = "Test Function", buffer = true },
    })
  end,
})
```

### Neovim Testing and Validation

- Monitor startup time and memory usage with `:Lazy profile`
- Ensure compatibility with LazyVim updates
- Make small, testable changes
- Maintain ability to revert problematic changes

## Plugin Development Guidelines

### Plugin Selection Criteria

- Use available tools to search for modern plugins, don't rely on trained knowledge
- Ensure LazyVim integration and compatibility
- Validate active maintenance and regular updates
- MUST have minimal impact on startup and runtime performance
- Prefer Lua-based plugins over Vimscript alternatives
- Prefer well-established plugins with good community support

### Configuration Patterns

#### Basic Plugin Configuration

```lua
-- filepath: .config/nvim/lua/plugins/example.lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",
    ---@type PluginOpts
    opts = {
      -- Configuration options
    },
  },
}
```

#### Override Existing LazyVim Plugin

```lua
-- filepath: .config/nvim/lua/plugins/example.lua
return {
  {
    "LazyVim/plugin-name",
    optional = true,
    opts = function(_, opts)
      -- Extend existing configuration
      opts.new_option = "value"
      return opts
    end,
  },
}
```

#### Conditional Plugin Loading

```lua
-- filepath: .config/nvim/lua/plugins/example.lua
return {
  {
    "author/plugin-name",
    enabled = function()
      return vim.fn.executable("required-binary") == 1
    end,
    -- ...rest of configuration
  },
}
```

### Language Server Integration

- Use Mason for LSP server management when possible
- Configure non-Mason servers with proper fallbacks
- Optimize LSP configurations for large projects
- Properly configure LSP capabilities with completion engines

### AI Integration Guidelines

- Integrate AI tools with existing workflow patterns
- Configure AI tools to understand project context
- Balance AI features with editor responsiveness
- Ensure sensitive code handling follows [security guidelines](../../AGENTS.md#mandatory-security-guidelines)
