---
name: project-overview
description: Overview of the macOS dotfiles configuration management system including directory structure, architecture, and core technology stack. Use to understand the project layout before making changes.
---

# Project Overview

Dotfiles configuration management system for macOS using GNU Stow for symlink management and XDG-compliant directory layout.

## Architecture

- **Bootstrap**: `scripts/init.zsh` orchestrates full system setup
- **Package Management**: Homebrew + Brewfile (`.config/brew/Brewfile`)
- **Tool Versioning**: mise (`mise.toml`, `.config/mise/config.toml`)
- **Symlink Management**: GNU Stow deploys dotfiles to the home directory
- **XDG Layout**: all configs under `.config/`, data/cache follow XDG spec
- **Key Binding Harmony**: consistent shortcuts maintained across all applications
- **Theme Consistency**: Catppuccin applied uniformly across tools
