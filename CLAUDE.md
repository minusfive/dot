# macOS System Configuration Project

## Project Overview

This project is focused on macOS system configuration, including configuration files for various tools, scripts, and applications. The project includes configurations for Neovim, Hammerspoon, WezTerm, Zsh, and many other tools.

## System Configuration Context

You are an expert in macOS system configuration, neovim configuration, hammerspoon configuration, wezterm configuration, zsh scripting, lua scripting, and dotfiles management. Use the provided context to answer questions or generate code related to system setup, configuration, and automation.

## Project Structure

The project is organized into the following groups:

### Setup Scripts

These are zsh scripts used for system setup, software installation, and configuration:

- `scripts/brew.zsh`: Homebrew installation and management
- `scripts/functions.zsh`: Reusable shell functions
- `scripts/init.zsh`: System setup initialization
- `scripts/mise.zsh`: Tool version manager setup
- `scripts/os.zsh`: OS-specific configuration
- `scripts/symlink.zsh`: Symlink management
- `scripts/vm.zsh`: Virtual machine setup
- `scripts/zsh.zsh`: Zsh shell configuration

### Hammerspoon Configurations

Configuration files for Hammerspoon automation:

- `.config/hammerspoon/init.lua`: Main Hammerspoon configuration
- `.config/hammerspoon/Spoons/AppLauncher.spoon/init.lua`: App launcher
- `.config/hammerspoon/Spoons/Caffeine.spoon/init.lua`: Caffeine spoon
- `.config/hammerspoon/Spoons/EmmyLua.spoon/init.lua`: EmmyLua integration
- `.config/hammerspoon/Spoons/Hotkeys.spoon/init.lua`: Hotkey configuration
- `.config/hammerspoon/Spoons/WindowManager.spoon/init.lua`: Window management

### Neovim Configurations

Configuration files for Neovim:

- `.config/nvim/init.lua`: Main Neovim configuration
- Various filetype plugins in `.config/nvim/after/ftplugin/`
- Core configurations in `.config/nvim/lua/config/`
- Plugin configurations in `.config/nvim/lua/plugins/`
- Language-specific configurations in `.config/nvim/lua/plugins/lang/`

### WezTerm Configurations

- `.config/wezterm/wezterm.lua`: WezTerm terminal emulator configuration
- `.config/wezterm/shell-completion.zsh`: WezTerm shell completions
- `.config/wezterm/shell-integration.zsh`: WezTerm shell integration

### Ghostty Configurations

- `.config/ghostty/config`: Ghostty terminal emulator configuration
- `.config/ghostty/shaders/cursor_smear.glsl`: Custom cursor shader
- `.config/ghostty/shaders/cursor_smear_fade.glsl`: Custom cursor fade shader
- `.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl`: Custom synesthesia cursor shader

### Yazi Configurations

- `.config/yazi/init.lua`: Yazi file manager configuration
- `.config/yazi/plugins/no-status.yazi/main.lua`: No-status UI plugin

### Additional Tool Configurations

This project also includes configurations for:

- bat (syntax highlighter)
- brew (Homebrew)
- btop (resource monitor)
- colortail (log colorizer)
- fd (file finder)
- fzf (fuzzy finder)
- git
- GitHub Copilot
- lazygit
- mcphub (server configuration)
- mise (tool version manager)
- ripgrep
- tmux
- zellij (terminal multiplexer)
- Zsh
- 1Password (SSH agent)
- harper (dictionary)
- GNU stow
- ghostty (terminal emulator)
- delta (git diff viewer)

## Code Style Guidelines

- Use consistent indentation (2 spaces for most files)
- Follow language-specific conventions for each configuration file
- Include descriptive comments for complex configurations
- Keep configurations modular and organized

## Common Development Tasks

- Use GNU stow for symlink management
- Test Neovim configurations with `tests/nvim/repro.lua`
- Use mise.toml for tool version management
- Configure plugins via their respective configuration files
- Use Lima and Podman for virtualization and containerization
- Use the AI development tools (vectorcode) for codebase navigation and assistance

## AI Development

This project includes support for AI development tools:

- Setup using Lima and Podman for virtualization
- Container orchestration using Docker Compose
- VectorCode for semantic code search and navigation
- Integration with AI assistants for development help

To set up the AI services:

1. Start Lima VM with `limactl start podman`
2. Start AI services with `podman compose up --build -d`
3. Index/vectorize files with `vectorcode vectorize`

## Project Dependencies

- Homebrew for package management
- mise for tool version management
- Various terminal utilities (fzf, ripgrep, fd, etc.)
- Neovim and its plugins
- Hammerspoon and its spoons
- WezTerm terminal emulator
- Zsh shell and its plugins

## Configuration Best Practices

- Keep configurations modular and organized
- Use symlinks for easy management
- Leverage existing tools and plugins before creating custom solutions
- Document complex configurations with comments
- Test configurations in isolated environments before applying globally
