# macOS System Configuration Project - AI Rules and Guidelines

Comprehensive dotfiles configuration management system for macOS. Core technologies: Neovim, Hammerspoon, WezTerm/Ghostty, Zsh, development automation.

## READ FIRST: MANDATORY Rules and Guidelines

- [MANDATORY: AI Agent Interaction Rules](#mandatory-ai-agent-interaction-rules)
- [MANDATORY: Updating AGENTS.md](#mandatory-updating-agentsmd)
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
  - Strike-through rejected items and note reason

#### Task Plan Template

```markdown
### {{ TASK }} - Task Plan

- [ ] Step 1: Brief description
- [ ] Step 2: Brief description
- [ ] Step 3: Brief description
```

### MANDATORY: Updating AGENTS.md

When modifying this file, MUST follow all rules in [Markdown](#markdown) section, plus:

- **Document Rationale**: Explain why changes are needed before implementing
- **Follow Code Change Philosophy**: Apply [Code Change Philosophy](#code-change-philosophy) principles to documentation
- **Use Directive Language**: Write rules using concise, imperative instructions (e.g., "Use X" not "Should use X", "Avoid Y" not "Try to avoid Y")

### IMPORTANT: Communication Guidelines

#### Response Style

- Be concise and direct, answering in fewer than 4 lines unless detail is requested
- Minimize output tokens by addressing only the specific task
- Skip preambles like "Here is what I'll do..." or "Based on the information..."
- Brief answers are best, use 1-3 sentences when possible
- Keep all communication text-based unless explicitly requested (no emojis or icons)

#### Professional Objectivity

- Prioritize technical accuracy and facts over validating beliefs
- Provide honest, objective feedback even when it may not align with expectations
- Investigate uncertainty first rather than confirming assumptions
- Apply rigorous standards consistently to all ideas

#### Tool Usage

- Do not explain or narrate exploration process before making tool calls
- Make tool calls silently and let results speak for themselves

#### Code Formatting

- Include `// filepath: path/to/file` in code blocks
- Use `// ...existing code...` for unchanged sections
- Specify correct language in code blocks
- Escape `<<<<<<<`, `=======`, `>>>>>>>` with backslashes

#### When to Ask Questions

- Confidence is below 90%
- Requirements are ambiguous
- Multiple approaches possible
- Configuration impact unclear
- Tool preferences unknown
- Security implications exist

### IMPORTANT: Tool Usage Efficiency

#### Parallel Operations

- Make ALL independent tool calls in a SINGLE response
- Never make sequential turns for operations that can run in parallel
- Examples of parallel operations: reading multiple files, viewing multiple directories, validating multiple changes
- Use sequential operations only when tool calls depend on previous results for parameter values

#### Efficiency Patterns

- Read larger file sections using offset and limit parameters
- Use command chains with `&&` or batch operations
- Minimize tool output with `--quiet`, `--no-pager`, or pipe to `grep`/`head`
- Use recursive patterns with globs or batch operations in single tool calls

#### Directory Analysis

Use `eza --tree --level=n`. Start with level 2, increase selectively for detail.

- `--level=2 .config/` for configuration overview
- `--level=3 scripts/` for script organization
- `--level=4 .config/nvim/` for Neovim structure
- `--all --level=2` to include hidden files
- `--only-dirs --level=3` for directory structure only

## MANDATORY: Coding Guidelines

### Code Change Philosophy

- Make minimal modifications, changing as few lines as possible
- Make changes surgical and precise
- Never delete or modify working code unless absolutely necessary
- Ignore unrelated bugs or broken tests
- Fix only build/test failures related to your task
- Always validate that changes don't break existing behavior
- Update only documentation directly related to your changes

### General Principles

- Adhere to documented coding standards for each language or module
- Prefer functional over Object Oriented patterns
- Suggest testable and reversible changes (see [Testing and Validation](#testing-and-validation))
- Include robust error handling in all scripts
- Organize configurations for easy maintenance
- Maintain established organization patterns
- Use XDG Base Directory specification
- Keep existing documentation up to date
- Only add comments if they match existing style or explain complex changes
- Use existing libraries whenever possible
- Only add new libraries or update versions if absolutely necessary

### Linting, Building, and Testing

- Only run existing tools, don't add new ones unless necessary for the task
- Run existing linters, builds, and tests before making changes to understand unrelated issues
- Lint, build, and test changes as soon as possible after making them
- Documentation changes don't need linting/building/testing unless specific tests exist

### Using Ecosystem Tools

- Prefer tools from the ecosystem to automate tasks and reduce mistakes
- Always use scaffolding tools like `npm init` or `yeoman` for new applications
- Use package managers (`npm install`, `pip install`) for dependency updates
- Use refactoring tools to automate changes
- Use linters and formatters to fix code style and correctness

### Testing and Validation

- Define acceptance criteria first
- Create tests validating expected behavior
- Implement incrementally to pass tests
- Validate continuously during development
- Test in isolated environments

### Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- Use local variables to limit scope
- Always add and update type annotations
- Organize `---@module` references at the top of the file, sorted alphabetically
- Use explicit module returns and clear structure
- Add LuaDoc-style comments for complex functions
- For tool-specific patterns, see:
  - [.config/nvim/AGENTS.md](.config/nvim/AGENTS.md) - Neovim configuration
  - [.config/hammerspoon/AGENTS.md](.config/hammerspoon/AGENTS.md) - Hammerspoon automation

### Shell Scripts (Zsh)

- Use `set -euo pipefail` for error handling
- Use consistent logging functions
- For setup scripts in `scripts/`, see [scripts/AGENTS.md](scripts/AGENTS.md) for detailed guidelines

### Configuration Files

- Consistent key naming conventions
- Logical grouping with fallback values
- Modular structure separating concerns

### Markdown

- Avoid duplication of content, prefer link references to existing sections
- Be clear and succinct
- Use proper headings instead of `**Title**:` for section headers
  - Allow `**Title**:` patterns within list items for clarity
- Validate heading hierarchy (H1→H2→H3→H4)
- Use bold for emphasis only, not section headers
- Use standard `[text](url)` links, not wiki-style
- Maintain consistent list formatting with hyphens for unordered lists
- Use `1.` for all ordered list items instead of sequential numbers
- Validate all anchor links after structural changes (lowercase, hyphenated)
- Keep table of contents synchronized with actual sections
- After completing changes, analyze file and suggest optimizations and deduplication opportunities

## MANDATORY: Version Control (Git) Guidelines

### IMPORTANT: Pre-Commit Guidelines

- Analyze [Commit Boundaries](#commit-boundaries)
- Break-down commit plan as specified in [MANDATORY: Task Planning](#mandatory-task-planning)
- Show complete diff `git diff --staged` in readable format with syntax highlighting
- Summarize key modifications
- Perform a full security analysis before committing (see [MANDATORY: Security Guidelines](#mandatory-security-guidelines))
- Request explicit approval, never auto-commit without user confirmation
- Suggest documentation updates if not included
- Validate reference integrity:
  - Validate all markdown links in documentation
  - Validate all path and structure references
  - Verify GNU Stow symlinks remain valid
  - Validate hardcoded paths in scripts/configs
  - Validate test file references

### IMPORTANT: Commit Guidelines

#### Message Format

Use "Conventional Commits" standard: `<type>[scope]: <description>`

Keep commit messages concise (50 characters or less for summary) but descriptive.

Examples:

- `feat(nvim): add new plugin configuration`
- `fix(zsh): resolve completion loading issue`
- `docs(README): update installation instructions`

#### Commit Boundaries

Separate commits for:

- Different functional areas (Neovim vs. Hammerspoon)
- Different change types (bugs vs. features)
- Independent concerns

Single commit for:

- Tightly coupled changes (implementation + tests)
- Atomic operations across multiple files
- Small related changes

### IMPORTANT: Pull Request Guidelines

#### PR Title Format

Follow [Commit Message Format](#message-format) with brief summary of all changes to be merged (72 characters or less).

#### PR Requirements

- All commits follow [Commit Guidelines](#important-commit-guidelines)
- Pass existing tests and linting
- Security review for system-level changes
- Reference integrity validation for documentation

### IMPORTANT: Branching Strategy

#### Branch Naming

Keep branch names short and descriptive: `fix-window-snapping`, `lsp-config`, `update-docs`

#### Workflow

- Main branch: `nixless`
- Create new branch for all new features or complex changes
- Simple fixes and typos may commit directly to `nixless`
- Keep branches short-lived
- Squash merge to `nixless` via PR
- Delete branch after merge

#### Before Merging

- Sync with latest `nixless`
- Run tests and linting
- Follow [Pre-Commit Guidelines](#important-pre-commit-guidelines)
- Get explicit approval

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
