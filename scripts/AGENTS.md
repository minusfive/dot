# System Setup Scripts - AI Rules and Guidelines

Bootstrap and system configuration scripts for macOS dotfiles setup. Core technologies: Zsh, Homebrew, GNU Stow, mise, macOS configuration.

## READ FIRST: MANDATORY Rules and Guidelines

**See [main AGENTS.md](../AGENTS.md) for core guidelines. This file contains scripts-specific extensions.**

- [Scripts Overview](#scripts-overview)
- [Script Development Guidelines](#script-development-guidelines)

### MANDATORY: Updating this File

Follow [main AGENTS.md updating rules](../AGENTS.md#mandatory-updating-agentsmd).

## Scripts Overview

### Directory Structure

```sh
scripts/
├── init.zsh              # Main entry point with option parsing
├── functions.zsh         # Shared utility functions (logging, colors, prompts)
├── brew.zsh             # Homebrew and package installation
├── symlink.zsh          # GNU Stow dotfile symlinking
├── mise.zsh             # Development tool version management
├── zsh.zsh              # Zsh theme and plugin installation
├── os.zsh               # macOS system settings configuration
├── vm.zsh               # Lima VM setup for containers
└── betterdisplay.zsh    # BetterDisplay settings management
```

### Architecture Overview

- **Entry Point**: `init.zsh` orchestrates all setup operations with option flags
- **Modular Scripts**: Each script handles a specific setup domain
- **Shared Functions**: `functions.zsh` provides consistent logging and user interaction
- **Scoped Execution**: All scripts use immediately invoked functions for variable isolation
- **Error Handling**: `set -euo pipefail` enforces strict error handling
- **Interactive Prompts**: User confirmation required for destructive operations

### Script Purposes

- **init.zsh**: Parse options, coordinate execution of other scripts
- **functions.zsh**: Logging (`_v_log_*`), formatting (`_v_fmt_*`), colors (`_v_color_*`), user prompts
- **brew.zsh**: Install Homebrew, run `brew bundle` with Brewfile
- **symlink.zsh**: Use GNU Stow to create symlinks from dotfiles to home directory
- **mise.zsh**: Install and configure mise for dev tool version management
- **zsh.zsh**: Install Oh My Zsh, Powerlevel10k theme, and plugins
- **os.zsh**: Configure macOS defaults using `defaults write` commands
- **vm.zsh**: Set up Lima VMs for rootless container management
- **betterdisplay.zsh**: Import/export BetterDisplay monitor settings

## Script Development Guidelines

### Zsh Script Standards

Follow [main AGENTS.md Shell Scripts guidelines](../AGENTS.md#shell-scripts-zsh).

### Script Architecture Pattern

All scripts follow this structure:

```zsh
#!/usr/bin/env zsh

# Brief description of script purpose

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function used to contain variables and functions scope
function {
    local __var_name="value"
    
    # Script logic here
    
    # Use logging functions from functions.zsh
    _v_log_info "CONTEXT" "Message"
}
```

### Naming Conventions

- **Script files**: Use descriptive lowercase names with `.zsh` extension
- **Internal variables**: Prefix with `__` (e.g., `__dotfiles_dir`, `__proceed`)
- **Shared functions**: Prefix with `_v_` (e.g., `_v_log_info`, `_v_confirm_proceed`)
- **Function categories**:
  - `_v_log_*`: Logging functions (error, info, ok, warn, q)
  - `_v_fmt_*`: Text formatting (bold, standout, underline)
  - `_v_color_*`: Color functions (foreground, background)

### Adding New Scripts

When adding new setup scripts:

1. Create script following architecture pattern above
1. Add option flag to `init.zsh` option parsing
1. Update `functions.zsh` help output with new option
1. Use existing logging functions for consistent output
1. Add confirmation prompts for destructive operations
1. Create tests in `../tests/scripts/` directory
1. Document script purpose in header comment

### Testing Scripts

Follow [main AGENTS.md Testing and Validation](../AGENTS.md#testing-and-validation), plus:

- Test scripts with `--noop` flag when available
- Test in isolated environment or VM before running on main system
- Verify idempotency (running multiple times produces same result)
- Test with both interactive and non-interactive modes
- Verify error handling with invalid inputs

### User Interaction Guidelines

- Use `_v_confirm_proceed` for destructive operations
- Provide clear context in logging messages
- Use appropriate log levels (error, warn, info, ok)
- Allow `--noop` or dry-run mode where applicable
- Show what will be changed before making changes

### macOS System Configuration

When modifying `os.zsh`:

- Document source of each `defaults write` command
- Group related settings logically
- Test settings are actually applied after script runs
- Provide rationale for non-obvious settings
- Note any settings requiring system restart or logout

### Integration with Main Setup Flow

- Scripts should be independently executable for testing
- Scripts should accept parameters for configuration
- Scripts should handle missing dependencies gracefully
- Scripts should integrate with `init.zsh` option system
- Scripts should use consistent exit codes

---

This configuration extends the main project guidelines with scripts-specific patterns for system setup automation.
