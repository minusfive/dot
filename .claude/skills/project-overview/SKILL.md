---
name: project-overview
description: Overview of the macOS dotfiles configuration management system including directory structure, architecture, and core technology stack. Use to understand the project layout before making changes.
---

# Project Overview

Dotfiles configuration management system for macOS. Core technologies: Neovim, Hammerspoon, WezTerm/Ghostty, Zsh, development automation.

## Directory Structure

```sh
./                      # macOS dotfiles configuration system
├── scripts/            # System setup and update scripts
├── tests/              # Tests directory
├── assets/             # Project assets (wallpapers, screenshots, etc.)
├── .config/            # XDG-compliant application configurations
├── mise.toml           # Project-specific tool versions
└── [config files]      # Stow, formatting, and project metadata
```

## Architecture Overview

- **Bootstrap Script** (`./scripts/init.zsh`): Main entry point to setup and update the system
- **Package Management**: Homebrew with Brewfile (`.config/brew/Brewfile`) for declarative package management
- **Tool Versioning**: mise for managing development tool versions
- **Symlink Management**: GNU Stow for dotfile deployment
- **Configuration and Data Sharing**: XDG directories for configuration and cache
- **Key Binding Harmony**: Consistent shortcuts across applications
- **Theme Consistency**: Catppuccin color scheme across tools

## Core Knowledge Requirements and Technology Stack

- System configuration and automation
- Neovim configuration and plugin management
- Hammerspoon automation and window management
- Terminal emulator configuration (WezTerm, Ghostty)
- Zsh scripting and shell customization
- Lua scripting for configuration files
- Dotfiles management with GNU Stow
- Container orchestration (Lima, Podman, Docker)

## Development Tools Configuration

- `mise.toml`: This project's specific tool versions and environment
- `.config/mise/config.toml`: Global tool versions and environment configuration
- `compose.yaml`: Docker Compose services for development
- Lima integration for Linux VM management
- Podman for rootless container management
