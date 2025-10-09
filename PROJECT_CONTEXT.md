# Project Context

## Project Structure

```sh
dot/                              # macOS dotfiles configuration system
├── scripts/                      # Zsh-based setup automation and bootstrapping
├── tests/                        # Testing framework for configurations and scripts
├── assets/                       # Project assets (wallpapers, screenshots, media)
├── .config/                      # XDG-compliant application configurations
├── compose.yaml                  # Docker services for development
├── mise.toml                     # Project-specific tool versions
└── [config files]               # Stow, formatting, and project metadata
```

### Key Directories

- **`scripts/`**: Bootstrap system with Zsh automation for package management, symlinks, and system setup
- **`.config/`**: XDG Base Directory compliant configurations for all applications (nvim, hammerspoon, terminals, etc.)
- **`tests/`**: Comprehensive testing suite for both Neovim configurations and setup scripts
- **`assets/`**: Static resources including wallpapers, screenshots, and documentation media

## Architecture Overview

### Core Setup System

- **Bootstrap Script**: Main entry point via setup scripts
- **Package Management**: Homebrew with Brewfile (`.config/brew/Brewfile`) for declarative package management
- **Tool Versioning**: mise for managing development tool versions
- **Symlink Management**: GNU Stow for dotfile deployment
- **Configuration Organization**: XDG Base Directory compliant structure

### Tool Integration Patterns

- **Shell Integration**: Common environment variables and paths
- **Theme Consistency**: Catppuccin color scheme across tools
- **Key Binding Harmony**: Consistent shortcuts across applications
- **Data Sharing**: XDG directories for configuration and cache

## Project Setup Scripts (`scripts/`)

Zsh-based setup automation:

- `betterdisplay.zsh`: BetterDisplay settings export/import management
- `brew.zsh`: Homebrew and package installation with profile support
- `functions.zsh`: Reusable utility functions for setup scripts
- `init.zsh`: System initialization and bootstrapping
- `mise.zsh`: Development tool version management setup
- `os.zsh`: System-specific configuration
- `symlink.zsh`: Automated dotfile symlinking with GNU Stow
- `vm.zsh`: Lima VM and containerization setup
- `zsh.zsh`: Zsh shell configuration and plugin management

## Application Configurations

### Hammerspoon (`/.config/hammerspoon/`)

macOS automation platform:

- `init.lua`: Main configuration loader
- `Spoons/AppLauncher.spoon/`: Application launching automation
- `Spoons/Caffeine.spoon/`: System sleep prevention
- `Spoons/EmmyLua.spoon/`: Lua development support
- `Spoons/Hotkeys.spoon/`: Global hotkey management
- `Spoons/WindowManager.spoon/`: Window management and tiling

### Neovim (`/.config/nvim/`)

Advanced text editor configuration:

- `init.lua`: Main entry point and configuration loader
- `lua/config/`: Core Neovim settings (autocmds, keymaps, options)
- `lua/plugins/`: Plugin specifications and configurations
- `lua/plugins/lang/`: Language-specific configurations
- `after/ftplugin/`: Filetype-specific customizations
- `tests/nvim/repro.lua`: Minimal reproduction environment

### Terminal Emulators

- **WezTerm** (`.config/wezterm/`): Primary terminal with shell integration
- **Ghostty** (`.config/ghostty/`): Alternative terminal with custom shaders

### File Management

- **Yazi** (`.config/yazi/`): Terminal file manager with custom plugins

## Development Tools Configuration

### Tool Version and Environment Management

- `mise.toml`: This project's specific tool versions and environment
- `.config/mise/config.toml`: Global tool versions and environment configuration

### Git and Version Control

- `.config/git/config`: Global Git settings and aliases
- `.config/git/ignore`: Global Git ignore patterns
- `.config/lazygit/config.yml`: Lazygit (Terminal UI for Git operations) configuration

### Container and Virtualization

- `compose.yaml`: Docker Compose services for development
- Lima integration for Linux VM management
- Podman for rootless container management

### Additional Tools

Configurations for:

- `bat`: Syntax highlighting with custom themes
- `btop`: System resource monitoring
- `BetterDisplay`: macOS display management and HiDPI scaling
- `fzf`: Fuzzy finding with custom key bindings
- `ripgrep`: Fast text search (configured via command-line options)
- `zellij`: Terminal multiplexer alternative to tmux
- `1Password`: SSH agent integration
- `harper`: Spell checking and dictionary management

### Display Management

- **BetterDisplay** (`.config/BetterDisplay/`): Display utility configuration
  - `config.plist`: Main settings export/import file
  - `README.md`: Configuration documentation and troubleshooting
  - Automated backup system for settings before imports
  - Cross-system compatibility guidance for display-specific settings

## Project Development Workflow

### Setup Process

1. **Initial Setup**: Run bootstrap script with profile selection
1. **Package Installation**: Homebrew manages system and development tools
1. **Symlink Creation**: GNU Stow creates symlinks to configuration files
1. **Tool Installation**: mise manages development tool versions
1. **Shell Configuration**: Zsh with custom functions and completion

### AI Development Integration

- **AI Assistant Guidelines**: See [AGENTS.md](./AGENTS.md) for comprehensive interaction rules, security protocols, implementation standards, and task planning requirements
- **VectorCode Usage**: Semantic search and code analysis
- **Container Development**: Lima/Podman for AI services
- **Code Indexing**: Intelligent navigation and suggestions

## Project Dependencies and Requirements

### Core Dependencies

- **macOS**: Primary target platform
- **Homebrew**: Package management foundation
- **GNU Stow**: Symlink management system
- **Zsh**: Advanced shell with completion support

### Development Tools

- **mise**: Multi-language tool version management
- **Git**: Version control with enhanced workflows
- **Neovim**: Primary text editor with extensive plugin ecosystem
- **Lima/Podman**: Containerization and virtualization

### Optional Enhancements

- **Hammerspoon**: macOS automation and window management
- **Terminal Emulators**: WezTerm or Ghostty with advanced features
- **File Management**: Yazi for enhanced terminal file operations
- **System Monitoring**: btop, htop for system resource monitoring
- **Display Management**: BetterDisplay for advanced display scaling and management
