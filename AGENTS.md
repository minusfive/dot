# macOS System Configuration Project - AI Rules and Guidelines

## Project Overview

This project is a comprehensive macOS dotfiles configuration management system, focusing on system automation, development environment setup, and productivity tools. The project includes configurations for Neovim, Hammerspoon, WezTerm/Ghostty terminals, Zsh shell, and numerous development tools.

## System Configuration Context

You are an expert in:

- macOS system configuration and automation
- Neovim configuration and plugin management
- Hammerspoon automation and window management
- Terminal emulator configuration (WezTerm, Ghostty)
- Zsh scripting and shell customization
- Lua scripting for configuration files
- Dotfiles management with GNU Stow
- Development tooling and workflow optimization
- Container orchestration and virtualization (Lima, Podman, Docker)

## Project Architecture

### Core Setup System

- **Bootstrap Script**: Main entry point via setup scripts
- **Package Management**: Homebrew with Brewfile for declarative package management
- **Tool Versioning**: mise for managing development tool versions
- **Symlink Management**: GNU Stow for dotfile deployment
- **Configuration Organization**: XDG Base Directory compliant structure

### Setup Scripts (`scripts/`)

Zsh-based setup automation:

- `betterdisplay.zsh`: BetterDisplay settings export/import management
- `brew.zsh`: Homebrew and package installation with profile support
- `functions.zsh`: Reusable utility functions for setup scripts
- `init.zsh`: System initialization and bootstrapping
- `mise.zsh`: Development tool version management setup
- `os.zsh`: macOS-specific system configuration
- `symlink.zsh`: Automated dotfile symlinking with GNU Stow
- `vm.zsh`: Lima VM and containerization setup
- `zsh.zsh`: Zsh shell configuration and plugin management

### Application Configurations

#### Hammerspoon (`/.config/hammerspoon/`)

macOS automation platform:

- `init.lua`: Main configuration loader
- `Spoons/AppLauncher.spoon/`: Application launching automation
- `Spoons/Caffeine.spoon/`: System sleep prevention
- `Spoons/EmmyLua.spoon/`: Lua development support
- `Spoons/Hotkeys.spoon/`: Global hotkey management
- `Spoons/WindowManager.spoon/`: Window management and tiling

#### Neovim (`/.config/nvim/`)

Advanced text editor configuration:

- `init.lua`: Main entry point and configuration loader
- `lua/config/`: Core Neovim settings (autocmds, keymaps, options)
- `lua/plugins/`: Plugin specifications and configurations
- `lua/plugins/lang/`: Language-specific configurations
- `after/ftplugin/`: Filetype-specific customizations
- `tests/nvim/repro.lua`: Minimal reproduction environment

#### Terminal Emulators

- **WezTerm** (`.config/wezterm/`): Primary terminal with shell integration
- **Ghostty** (`.config/ghostty/`): Alternative terminal with custom shaders

#### File Management

- **Yazi** (`.config/yazi/`): Terminal file manager with custom plugins

### Development Tools Configuration

#### Version Management

- `mise.toml`: Global tool versions and environment configuration
- `.config/mise/config.toml`: Mise-specific settings

#### Git and Version Control

- `lazygit`: Terminal UI for Git operations
- `.config/lazygit/config.yml`: Custom Git workflow configuration

#### Container and Virtualization

- `compose.yaml`: Docker Compose services for development
- Lima integration for Linux VM management
- Podman for rootless container management

#### Additional Tools

Configurations for:

- `bat`: Syntax highlighting with custom themes
- `btop`: System resource monitoring
- `BetterDisplay`: macOS display management and HiDPI scaling
- `fzf`: Fuzzy finding with custom key bindings
- `ripgrep`: Fast text search with configuration file
- `zellij`: Terminal multiplexer alternative to tmux
- `1Password`: SSH agent integration
- `harper`: Spell checking and dictionary management

#### Display Management

- **BetterDisplay** (`.config/BetterDisplay/`): macOS display utility configuration
  - `config.plist`: Main settings export/import file
  - `README.md`: Configuration documentation and troubleshooting
  - Automated backup system for settings before imports
  - Cross-system compatibility guidance for display-specific settings

## Code Style and Standards

### General Guidelines

- **Indentation**: 2 spaces for most configuration files
- **Language Conventions**: Follow each tool's recommended practices
- **Documentation**: Comprehensive comments for complex configurations
- **Modularity**: Keep configurations organized and easily maintainable
- **XDG Compliance**: Use XDG Base Directory specification where possible

### Commit Message Standards

- **Conventional Commits**: All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification
- **Format**: `<type>[optional scope]: <description>`
- **Common Types**:
  - `feat`: A new feature
  - `fix`: A bug fix
  - `docs`: Documentation only changes
  - `style`: Changes that do not affect the meaning of the code
  - `refactor`: A code change that neither fixes a bug nor adds a feature
  - `test`: Adding missing tests or correcting existing tests
  - `chore`: Changes to the build process or auxiliary tools
- **Examples**:
  - `feat(nvim): add new plugin configuration`
  - `fix(zsh): resolve completion loading issue`
  - `docs(README): update installation instructions`
  - `chore(brew): update package dependencies`

### Lua (Neovim, Hammerspoon, Yazi)

- Use local variables where appropriate
- Prefer explicit returns and clear module structure
- Document complex functions with LuaDoc-style comments
- Follow lazy loading patterns for Neovim plugins

### Shell Scripts (Zsh)

- Use `set -euo pipefail` for error handling
- Implement logging functions with consistent formatting
- Use immediately invoked functions for scope isolation
- Prefix internal variables with double underscores

### Configuration Files

- Use TOML for structured configuration where supported
- Maintain consistent key naming conventions
- Group related configurations logically
- Include fallback/default values where appropriate

## Development Workflow

### Setup and Installation

1. **Initial Setup**: Run bootstrap script with profile selection
2. **Package Installation**: Homebrew manages system and development tools
3. **Symlink Creation**: GNU Stow creates symlinks to configuration files
4. **Tool Installation**: mise manages development tool versions
5. **Shell Configuration**: Zsh with custom functions and completion

### Testing and Validation

- **Neovim Testing**: Use `tests/nvim/repro.lua` for isolated testing
- **Script Testing**: Comprehensive test suite in `tests/scripts/`
  - Unit tests for script integration and syntax
  - Integration tests for execution flow
  - Automated validation of help system integration
  - Error handling verification
- **Configuration Validation**: Test changes in isolated environments
- **Backup Strategy**: Version control all configuration changes
- **Rollback Capability**: Use Git for configuration history

### Container Development

AI development services setup:

1. **VM Management**: `limactl start podman` for Linux environment
2. **Service Orchestration**: `podman compose up --build -d` for AI services
3. **Code Indexing**: VectorCode for semantic search and navigation
4. **Development Assistance**: AI-powered code analysis and suggestions

## Tool Integration Patterns

### Cross-Tool Integration

- **Shell Integration**: Common environment variables and paths
- **Theme Consistency**: Catppuccin color scheme across tools
- **Key Binding Harmony**: Consistent shortcuts across applications
- **Data Sharing**: XDG directories for configuration and cache

### Plugin Management

- **Neovim**: Lazy.nvim for plugin management with lazy loading
- **Zsh**: Oh-My-Zsh framework with custom functions
- **Hammerspoon**: Spoon system for modular functionality
- **Yazi**: Custom plugins for enhanced file management

## AI Development Integration

### VectorCode Usage

- **Semantic Search**: Index configuration files for intelligent navigation
- **Code Analysis**: Understand configuration relationships and dependencies
- **Automated Suggestions**: AI-powered configuration improvements
- **Documentation**: Generate and maintain configuration documentation

### Development Assistance

- **Configuration Analysis**: Identify optimization opportunities
- **Dependency Management**: Track tool and plugin dependencies
- **Migration Support**: Assist with tool updates and migrations
- **Best Practice Enforcement**: Suggest improvements based on community standards

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

### Configuration Best Practices

### Organization

- **Modular Structure**: Separate concerns into focused configuration files
- **Version Control**: Track all configuration changes with meaningful commits following Conventional Commits standard
- **Documentation**: Comment complex configurations and decision rationale
- **Backup Strategy**: Regular backups of working configurations

### Maintenance

- **Regular Updates**: Keep tools and configurations current
- **Testing Protocol**: Validate changes before deployment
- **Rollback Plan**: Maintain ability to revert problematic changes
- **Performance Monitoring**: Track configuration impact on system performance

### Security

- **Credential Management**: Use 1Password for secure credential storage
- **Permission Management**: Apply principle of least privilege
- **Update Monitoring**: Track security updates for managed tools
- **Configuration Auditing**: Regular review of configuration security implications

## AI Assistant Guidelines

### When Analyzing This Project

1. **Understand Context**: Consider the macOS-centric nature and development focus
2. **Respect Structure**: Maintain the established organization patterns
3. **Follow Standards**: Adhere to the documented coding standards
4. **Test Recommendations**: Suggest testable and reversible changes
5. **Document Changes**: Explain rationale for suggested modifications

### Code Generation

- **File Path Comments**: Include `// filepath: path/to/file` in code blocks
- **Existing Code Preservation**: Use `// ...existing code...` to indicate unchanged sections
- **Language Specificity**: Use appropriate language identifiers in code blocks
- **Error Handling**: Include robust error handling in generated scripts
- **Test Coverage**: When adding new scripts, include corresponding tests in `tests/scripts/`
- **Commit Messages**: Always use Conventional Commits standard for all commit messages

### Script Integration Guidelines

When adding new setup scripts:

1. **Follow Naming Convention**: Use descriptive names matching the tool/service
2. **Bootstrap Integration**: Add new options to `init.zsh` with appropriate flags
3. **Help System**: Update `functions.zsh` to include new options in help output
4. **Error Handling**: Use established logging functions (`_v_log_*`) for consistent output
5. **User Interaction**: Implement confirmation prompts for destructive operations
6. **Cross-Platform**: Consider macOS-specific behaviors and dependencies
7. **Testing**: Create comprehensive test suite covering integration and execution
8. **Documentation**: Include README files for complex configurations

### BetterDisplay Integration Patterns

The BetterDisplay script exemplifies several key patterns for tool integration:

- **Interactive Decision Making**: Smart detection of existing configurations with user prompts
- **Backup Strategy**: Automatic backups before potentially destructive operations
- **Dependency Validation**: Check for required applications and provide helpful error messages
- **Cross-System Compatibility**: Handle display-specific settings that may not transfer between systems
- **State Management**: Detect and handle running applications that need to be closed for configuration changes

### Interaction Patterns

- **Incremental Changes**: Suggest small, testable modifications
- **Configuration Explanation**: Explain complex configuration decisions
- **Tool Recommendations**: Suggest tools that fit the existing ecosystem
- **Migration Assistance**: Help with tool updates and configuration changes
- **Operation Rejection Handling**: Always ask for an explanation and further instructions when an operation is rejected

This comprehensive guide should help AI assistants better understand and work with this sophisticated macOS configuration system.
