# macOS System Configuration Project - AI Rules and Guidelines

Comprehensive dotfiles configuration management system for macOS. Core technologies: Neovim, Hammerspoon, WezTerm/Ghostty, Zsh, development automation.

## READ FIRST: MANDATORY Rules and Guidelines

- [MANDATORY: AI Agent Interaction Rules](#mandatory-ai-agent-interaction-rules)
- [MANDATORY: Coding Guidelines](#mandatory-coding-guidelines)
- [MANDATORY: Version Control (Git) Guidelines](#mandatory-version-control-git-guidelines)
- [MANDATORY: Security Guidelines](#mandatory-security-guidelines)

## Project Overview

### Directory Structure

```sh
./                      # macOS dotfiles configuration system
├── scripts/            # System setup and update scripts
├── tests/              # Tests directory
├── assets/             # Project assets (wallpapers, screenshots, etc.)
├── .config/            # XDG-compliant application configurations
├── mise.toml           # Project-specific tool versions
└── [config files]      # Stow, formatting, and project metadata
```

### Architecture Overview

- **Bootstrap Script** (`./scripts/init.zsh`): Main entry point to setup and update the system
- **Package Management**: Homebrew with Brewfile (`.config/brew/Brewfile`) for declarative package management
- **Tool Versioning**: mise for managing development tool versions
- **Symlink Management**: GNU Stow for dotfile deployment
- **Configuration and Data Sharing**: XDG directories for configuration and cache
- **Key Binding Harmony**: Consistent shortcuts across applications
- **Theme Consistency**: Catppuccin color scheme across tools

### Core Knowledge Requirements and Technology Stack

- System configuration and automation
- Neovim configuration and plugin management
- Hammerspoon automation and window management
- Terminal emulator configuration (WezTerm, Ghostty)
- Zsh scripting and shell customization
- Lua scripting for configuration files
- Dotfiles management with GNU Stow
- Container orchestration (Lima, Podman, Docker)

### Development Tools Configuration

- `mise.toml`: This project's specific tool versions and environment
- `.config/mise/config.toml`: Global tool versions and environment configuration
- `compose.yaml`: Docker Compose services for development
- Lima integration for Linux VM management
- Podman for rootless container management

## MANDATORY: AI Agent Interaction Rules

### HIGHEST PRIORITY: When operations are rejected/fail

1. **STOP** current approach immediately
2. **ASK**: "I see that operation was rejected. Could you help me understand why?"
3. **REQUEST**: "What would you prefer I do instead?"
4. **WAIT** for instructions before proceeding
5. **NEVER** retry, or continue blindly, assume or generalize without guidance

### MANDATORY: Task Planning

- Present complete plan prior to execution using markdown checklist ([template](#task-plan-template))
- Explain rationale for modifications
- Execute steps sequentially
- Update and present checklist after each step
  - Mark completed items with `[x]`
  - Strike-through rejected items with and note reason

#### Task Plan Template

```markdown
### {{ TASK }} - Task Plan

- [ ] Step 1: Brief description
- [ ] Step 2: Brief description
- [ ] Step 3: Brief description
```

### IMPORTANT: Communication Guidelines

- **NO EMOJIS OR ICONS**: Keep all communication text-based unless explicitly requested
- **BE CLEAR, CONCISE and SUCCINCT**: Use simple language, avoid unnecessary verbosity
- **File Path Comments**: Include `// filepath: path/to/file` in code blocks
- **Preservation Markers**: Use `// ...existing code...` for unchanged sections
- **Language Identifiers**: Specify correct language in code blocks
- **SEARCH/REPLACE Safety**: Escape `<<<<<<<`, `=======`, `>>>>>>>` with backslashes
- **Ask clarifying questions when**:
  - Confidence is below 90%
  - Requirements are ambiguous
  - Multiple approaches possible
  - Configuration impact unclear
  - Tool preferences unknown
  - Security implications exist

### Directory Analysis

Use `eza --tree --level=n`. Start with level 2, increase selectively for detail.

- `--level=2 .config/` - Configuration overview
- `--level=3 scripts/` - Script organization
- `--level=4 .config/nvim/` - Neovim structure
- `--all --level=2` - Include hidden files
- `--only-dirs --level=3` - Directory structure only

## MANDATORY: Coding Guidelines

- **Standards**: Adhere to documented coding standards for each language or module
- **Functional Patterns**: Prefer functional over Object Oriented patterns
- **Test Driven Development (TDD)**: Suggest testable and reversible changes (MUST READ [Testing and Validation](#testing-and-validation))
- **Error Handling**: Include robust error handling in all scripts
- **Modularity**: Organize configurations for easy maintenance
- **Structure**: Maintain established organization patterns
- **XDG Compliance**: Use XDG Base Directory specification
- **Documentation**:
  - Keep existing documentation up to date
  - Comment complex configurations with rationale

### Testing and Validation

- Define acceptance criteria first
- Create tests validating expected behavior
- Implement incrementally to pass tests
- Validate continuously during development
- Test in isolated environments

### Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- Local variables where appropriate
- Always add and update type annotations
- Explicit module returns and clear structure
- LuaDoc-style comments for complex functions
- Lazy loading patterns for Neovim plugins

### Shell Scripts (Zsh)

- Error handling: `set -euo pipefail`
- Consistent logging functions
- Immediately invoked functions for scope
- Internal variables prefixed with `__`
- When adding setup scripts:
  - Add options to `init.zsh` with appropriate flags
  - Update `functions.zsh` help output
  - Use established logging functions
  - Add tests in `tests/scripts/`

### Configuration Files

- Consistent key naming conventions
- Logical grouping with fallback values
- Modular structure separating concerns

### Markdown

- Proper headings instead of `**Title**:` for section headers
  - Allow `**Title**:` patterns within list items for clarity
- Validate heading hierarchy (H1→H2→H3→H4)
- Bold for emphasis only, not section headers
- Standard `[text](url)` links, not wiki-style
- Consistent list formatting
  - Unordered lists with hyphens
  - Ordered with `1.` for all items instead of sequential numbers (`1., 2., 3.`)
- Validate all references, especially after refactoring

## MANDATORY: Version Control (Git) Guidelines

### IMPORTANT: Pre-Commit Guidelines

- Break-down commit plan as specified in [MANDATORY: Task Planning](#mandatory-task-planning)
- Show complete diff `git diff --staged` in readable format with syntax highlighting
- Summarize key modifications
- Perform a full security analysis before committing (see [MANDATORY: Security Guidelines](mandatory-security-guidelines))
- Request explicit approval, never auto-commit without user confirmation
- Suggest documentation updates if not included

### IMPORTANT: Commit Guidelines

- Format commit messages using the "Conventional Commits" standard (`<type>[scope]: <description>`)
  - Examples:
    - `feat(nvim): add new plugin configuration`
    - `fix(zsh): resolve completion loading issue`
    - `docs(README): update installation instructions`
- Commit messages should be concise (50 characters or less for summary) but descriptive
- Separate Commits For
  - Different functional areas (e.g. Neovim vs. Hammerspoon)
  - Different change types (e.g. bugs vs. features)
  - Independent concerns
- Single Commit For
  - Tightly coupled changes (implementation + tests)
  - Atomic operations across multiple files
  - Small related changes

### IMPORTANT: Reference Integrity

- Validate all markdown links on documentation
- Validate all path and structure references
- Verify GNU Stow symlinks remain valid
- Validate hardcoded paths in scripts/configs
- Validate test file references

## MANDATORY: Security Guidelines

- **NEVER** commit sensitive data to version control
- **Version Pinning**: Use specific versions for security-critical tools
- Enforce use of 1Password CLI for SSH agent and secrets management
- Follow least privilege principle, grant only the minimum necessary access and permissions
- Review system modification permissions carefully
- Validate permissions before script execution
- Ensure logs don't contain sensitive information
- Configure secure defaults for network-enabled tools
- Limit network access
