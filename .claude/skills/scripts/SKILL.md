---
name: scripts
description: AI rules and guidelines for system setup and bootstrap scripts using Zsh, Homebrew, GNU Stow, and mise. Use when working with setup scripts, automation, or system initialization in this dotfiles project.
---

# System Setup Scripts - AI Rules and Guidelines

## Script Architecture Pattern

All scripts follow this structure:

```zsh
# filepath: scripts/<name>.zsh
#!/usr/bin/env zsh

# Brief description of script purpose

set -euo pipefail

function {
    local __var_name="value"

    # Script logic here

    _v_log_info "CONTEXT" "Message"
}
```

## Naming Conventions

- **Script files**: descriptive lowercase names with `.zsh` extension
- **Internal variables**: prefix with `__` (e.g., `__dotfiles_dir`, `__proceed`)
- **Shared functions**: prefix with `_v_` (e.g., `_v_log_info`, `_v_confirm_proceed`)
- **Function categories**:
  - `_v_log_*`: logging (error, info, ok, warn, q)
  - `_v_fmt_*`: text formatting (bold, standout, underline)
  - `_v_color_*`: color (foreground, background)

## Adding New Scripts

1. Create script following the architecture pattern above
2. Add option flag to `init.zsh` option parsing
3. Update `functions.zsh` help output with new option
4. Add confirmation prompts for destructive operations
5. Create tests in `tests/scripts/` directory
6. Document script purpose in header comment

## Testing

- Test with `--noop` flag when available
- Test in isolated environment or VM before running on main system
- Verify idempotency — running multiple times must produce the same result
- Test with both interactive and non-interactive modes
- Verify error handling with invalid inputs

## User Interaction

- Use `_v_confirm_proceed` for destructive operations
- Use appropriate log levels (error, warn, info, ok)
- Support `--noop` / dry-run mode where applicable
- Show what will be changed before making changes

## macOS System Configuration (`os.zsh`)

- Document the source of each `defaults write` command
- Group related settings logically
- Provide rationale for non-obvious settings
- Note any settings requiring system restart or logout
- Test that settings are actually applied after the script runs

## Integration Requirements

- Scripts must be independently executable for testing
- Scripts must handle missing dependencies gracefully
- Scripts must use consistent exit codes

## Reusable Task Scripts

When a task requires a script for execution:

- Check `scripts/tasks/` for existing scripts that may apply
- Suggest modifications to existing scripts before creating new ones
- Make new scripts generic and reusable
- Save new scripts in `scripts/tasks/` for project-wide reuse
- Write script documentation optimized for AI agents, following [Markdown guidelines](../coding-guidelines/SKILL.md#markdown)
