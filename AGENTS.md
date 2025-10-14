# macOS System Configuration Project - AI Rules and Guidelines

> [!IMPORTANT]
> All rules and guidelines in this document are **MANDATORY**

## Project Overview

Dotfiles configuration management system for macOS. Core technologies: Neovim, Hammerspoon, WezTerm/Ghostty, Zsh, development automation.

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

## AI Agent Interaction Rules

### Core Principles

- Prioritize technical accuracy and facts over validating beliefs
- Provide honest, objective feedback even when it may not align with expectations
- Investigate uncertainty first rather than confirming assumptions
- Apply rigorous standards consistently to all ideas
- Be concise and direct, answering in fewer than 4 lines unless detail is requested
- Skip unnecessary preambles and postambles like "Here is what I'll do..." or "Based on the information..."
- DO NOT use emojis or icons unless explicitly requested
- Minimize output tokens by addressing only the specific task

### Task Planning

- Present complete plan prior to execution using markdown checklist (see [Template](#template))
- Explain rationale for modifications
- Execute steps sequentially
- Update and present checklist before and after each step
  - Mark completed items with `[x]`
  - Strike-through rejected or failed steps and note reason

#### Template

```markdown
### {{ TASK }} - Task Plan

- [ ] Step 1: Brief description
  - [ ] Step 1.1: Sub-step description
- [ ] Step 2: Brief description
- [ ] Step 3: Brief description
```

### When operations are rejected or fail

1. **STOP** current approach immediately
2. **ASK**: "Why was the operation rejected? What would you prefer I do instead?"
3. **WAIT** for instructions before proceeding
4. **DO NOT** retry or continue, assume or generalize without guidance

### When to Ask Questions

- Confidence is below 95%
- Requirements are ambiguous
- Multiple approaches possible
- Configuration impact unclear
- Tool preferences unknown
- Security implications exist

### Code Formatting

- Include `// filepath: path/to/file` in code blocks
- Use `// ...existing code...` for unchanged sections
- Specify correct language in code blocks
- Escape `<<<<<<<`, `=======`, `>>>>>>>` with backslashes

### Tool Usage and Efficiency

- Combine ALL independent tool calls in a SINGLE response
- Run operations in parallel when possible
  - Examples of parallel operations: reading multiple files, viewing multiple directories, validating multiple changes
- Use sequential operations only when tool calls depend on previous results for parameter values
- Read larger file sections using offset and limit parameters
- Use command chains with `&&` or batch operations
- Use homebrew or mise-managed tools for consistent analysis across environments
- Minimize tool output with `--quiet`, `--no-pager`, or pipe to `grep`/`head`
- Use `rg` instead of `grep` when available
- Use recursive patterns with globs or batch operations in single tool calls
- Use `eza` for deep directory analysis when available
- Use VectorCode for semantic analysis
- Use language servers and linters for diagnostics, rule analysis and suggestions

### Generate and save reusable scripts for task execution

When a task requires generating scripts for execution:

- Save scripts in `scripts/tasks/` directory for project-wide reuse
- Check `scripts/tasks/` directory for existing scripts which may be used to execute current task
- Suggest modifications to existing scripts if required to execute the current task and improve future reusability
- Make new scripts generic and reusable
- Use Bun with strict TypeScript types for all new scripts, tested with `bun test` following [Coding Guidelines](#coding-guidelines)
- Use kebab-case with descriptive names (e.g., `analyze-config.ts`, `validate-symlinks.ts`)
- Make scripts executable with proper shebang: `#!/usr/bin/env bun`
- Write documentation to each script optimized for AI agents, following [Markdown](#markdown)

## Coding Guidelines

### Core Coding Principles

- Explain why changes are needed before implementing
- Use a test-driven, red-green-refactor approach
- Make minimal modifications, changing as few lines as possible
- Make surgical and precise changes
- Make testable and reversible changes
- DO NOT delete or modify working code unless absolutely necessary
- Fix only build/test failures related to your task
- Validate that changes don't break existing behavior
- Update only documentation directly related to your changes
- Adhere to documented coding standards for each language or module
- Use functional patterns, avoid Object Oriented
- Organize configurations for easy maintenance
- Maintain established organization patterns
- Use XDG Base Directory specification
- Keep existing documentation up to date
- Only add comments if they match existing style or explain complex changes
- Use existing libraries whenever possible
- Only add new libraries or update versions if absolutely necessary
- After completing changes always validate all rules were followed

### Error Handling

- Include robust error handling in all scripts
- Use `set -euo pipefail` for shell scripts
- Add JSDoc comments for complex functions in TypeScript
- Include validation for all user inputs and system states

### Testing and Validation

- Define acceptance criteria first
- Create tests validating expected behavior
- Implement incrementally to pass tests
- Validate continuously during development
- Test in isolated environments
- Run existing linters, builds, and tests before making changes to understand unrelated issues
- Lint, build, and test changes as soon as possible after making them

### Approval and Safety

- Request explicit approval, never auto-commit without user confirmation
- Perform full security analysis before committing
- Validate reference integrity: markdown links, path references, GNU Stow symlinks, hardcoded paths, test file references

### Use Ecosystem Tools

- Prefer tools from the ecosystem to automate tasks and reduce mistakes
- Always use scaffolding tools like `npm init` or `yeoman` for new applications
- Use package managers (`npm install`, `pip install`) for dependency updates
- Use refactoring tools to automate changes
- Use linters and formatters to fix code style and correctness

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
- Maintain consistent list formatting
  - Hyphens for unordered lists
  - Sequential numbers for ordered lists
- Validate all anchor links after structural changes (lowercase, hyphenated)
- DO NOT create table of contents unless explicitly requested
  - If one exists, keep it synchronized with actual sections
- Always analyze the whole file and suggest optimizations according to these rules

#### When updating AGENTS.md or other AI rules files

- Write concise imperative rules optimized for efficient and accurate AI agent execution

## Version Control (Git) Guidelines

### Pre-Commit Guidelines

- Analyze [Commit Boundaries](#commit-boundaries)
- Break-down commit plan as specified in [Task Planning](#task-planning)
- Show complete diff `git diff --staged` in readable format with syntax highlighting
- Summarize key modifications
- Perform a full security analysis before committing (see [Security Guidelines](#security-guidelines))
- Suggest documentation updates if not included

### Commit Guidelines

#### Message Format

Use "Conventional Commits" standard: `<type>[scope]: <description>`

Keep messages under 50 characters for summary but descriptive.

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

### Pull Request Guidelines

#### Title Format

Follow [Message Format](#message-format) with summary of all changes to be merged

#### Requirements

- Pass existing tests and linting
- Security review for system-level changes
- Reference integrity validation for documentation

### Branching Strategy

#### Branch Naming

Keep branch names short and descriptive: `fix-window-snapping`, `lsp-config`, `update-docs`

#### Workflow

- Main branch: `nixless`
- Create new branch for all new features or complex changes
- Simple fixes and typos may commit directly to `nixless`
- Keep branches short-lived
- Squash merge to `nixless` via pull request
- Delete branch after merge

#### Before Merging

- Sync with latest `nixless`
- Run tests and linting
- Follow [Error Handling and Validation Standards](#error-handling-and-validation-standards)

## Security Guidelines

- **NEVER** commit sensitive data to version control
- **Version Pinning**: Use specific versions for security-critical tools
- Enforce use of 1Password CLI for SSH agent and secrets management
- Follow least privilege principle, grant only the minimum necessary access and permissions
- Review system modification permissions carefully
- Validate permissions before script execution
- Ensure logs don't contain sensitive information
- Configure secure defaults for network-enabled tools
- Limit network access and validate all external connections
