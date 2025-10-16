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

- Must always present a plan before executing (see [Task Planning](#task-planning))
- Prioritize technical accuracy and facts over validating beliefs
- Provide honest, objective feedback even when it may not align with expectations
- Investigate uncertainty first rather than confirming assumptions
- Apply rigorous standards consistently to all ideas
- Be concise and direct, answering in fewer than 4 lines unless detail is requested
- Skip unnecessary preambles and postambles like "Here is what I'll do..." or "Based on the information..."
- DO NOT use emojis or icons unless explicitly requested
- Minimize output tokens by addressing only the specific task

### Task Planning

- Present complete plan prior to execution using markdown checklist (see [Task Planning Template](#task-planning-template))
- Follow the plan strictly unless explicitly instructed otherwise
- Explain rationale for modifications
- Execute steps sequentially
- Update and present checklist before and after each step is completed, rejected or skipped
  - Mark completed items with `[x]`
  - Strike-through rejected or failed steps and note reason

#### Task Planning Template

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

- When confidence is below 95%
- When security implications exist
- When requirements are ambiguous
- When multiple approaches possible
- When configuration impact is unclear
- When tool preferences are unknown

### Code Formatting

- Include `// filepath: path/to/file` in code blocks
- Use `// ...existing code...` for unchanged sections
- Specify correct language in code blocks
- Escape `<<<<<<<`, `=======`, `>>>>>>>` with backslashes

### Tool Usage and Efficiency

- Combine ALL independent tool calls in a SINGLE response
- Call tools in parallel when possible; use sequential calls only when parameters depend on previous results
- Read larger file sections using offset and limit parameters
- Use command chains with `&&`, globs, or batch operations for single tool calls
- Use homebrew or mise-managed tools for consistent analysis across environments
  - See `./.config/brew/Brewfile`, `./.config/mise/config.toml` and `./mise.toml` for a full list of available tools
- Minimize tool output with `--quiet`, `--no-pager`, or pipe to `rg`/`head`
- Use VectorCode for semantic analysis
- Use language servers and linters for static analysis

### Generate and save reusable scripts for task execution

When a task requires generating scripts for execution:

- Check `scripts/tasks/` directory for existing scripts which may be used to execute current task
- Suggest modifications to existing scripts if required to execute the current task and improve future reusability
- Make new scripts generic and reusable
- Save scripts in `scripts/tasks/` directory for project-wide reuse
- Write documentation to each script optimized for AI agents, following [Markdown](#markdown)

### When analyzing and updating AI rules files (AGENTS.md, CLAUDE.md, etc.)

- Write concise rules using imperative language, optimized for accurate and efficient agentic communication and execution
- MUST follow the [Markdown](#markdown) guidelines strictly
- MUST analyze exclusively the literal contents of the file in isolation
  - MUST NOT include system or other prompts added to the context by tools or clients

## Coding Guidelines

### Core Coding Principles

- Explain why changes are needed before implementing
- Follow TDD strictly:
  - Write acceptance tests first, implement second
  - Define acceptance criteria first
  - Implement incrementally to pass tests (Red, Green)
  - Validate continuously during development
  - Test in isolated environments
- Adhere to documented coding standards for each language or module
- DO NOT delete or modify working code unless absolutely necessary
- Make minimal modifications, changing as few lines as possible
- Make surgical and precise, testable and reversible changes
- Fix only build or test failures related to your task
- Validate that changes don't break existing behavior
- Use functional patterns, avoid Object Oriented
- Maintain established organization patterns
- Use XDG standard directories
- Organize configurations for easy maintenance
- Update only documentation directly related to your changes
- Keep existing documentation up to date
- Only add comments if they match existing style or explain complex changes
- Use existing libraries whenever possible
- Only add new libraries or update versions if absolutely necessary
- After completing changes always validate all rules were followed
- Handle all errors
- Validate all user inputs and system states
- Run linters, builds, and tests before making changes to understand unrelated issues
- Prefer tools from the ecosystem to automate tasks and reduce mistakes
- Use refactoring tools to automate changes
- Use linters and formatters to fix code style and correctness
- Use local variables to limit scope
- Always add and update type annotations

### Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- Organize `---@module` references at the top of the file, sorted alphabetically
- Use explicit module returns and clear structure
- For tool-specific patterns, see:
  - [.config/nvim/AGENTS.md](.config/nvim/AGENTS.md) - Neovim configuration
  - [.config/hammerspoon/AGENTS.md](.config/hammerspoon/AGENTS.md) - Hammerspoon automation

### Shell Scripts (Zsh)

- Use consistent logging functions
- Use `set -euo pipefail` for error safety
- For setup scripts in `scripts/`, see [scripts/AGENTS.md](scripts/AGENTS.md) for detailed guidelines

### Configuration Files

- Consistent key naming conventions
- Logical grouping with fallback values
- Modular structure separating concerns

### Markdown

- Be clear and succinct
- DO NOT write redundant or duplicate content, use link references
- Use standard `[text](url)` links, not wiki-style
- Validate all reference links after changes
- DO NOT create table of contents unless explicitly requested
  - If one exists, keep it synchronized with actual sections
- Always analyze the whole file and suggest optimizations according to these rules
- Validate markdown files using `markdownlint-cli2` configured in `.markdownlint-cli2.jsonc`

## Version Control (Git) Guidelines

### Commit Guidelines

#### Before Committing

- Analyze [Commit Boundaries](#commit-boundaries)
- Break-down commit plan as specified in [Task Planning](#task-planning)
- Summarize key modifications
- Perform a full security analysis before committing (see [Security Guidelines](#security-guidelines))
- Validate documentation
- Validate reference integrity: markdown links, path references, GNU Stow symlinks, hardcoded paths, test file references
- Request explicit approval, never auto-commit without user confirmation

#### Commit Boundaries

- Create separate commits for:
  - Different functional areas
  - Different change types
  - Independent concerns
- Create a single commit for:
  - Tightly coupled changes (implementation + tests)
  - Atomic operations across multiple files
  - Small related changes

#### Commit Message Format

- Write concise messages (`< 50` characters) following the "Conventional Commits" standard format: `<type>(<scope>): <summary>`
  - Types:
    - `feat`: New feature or enhancement
    - `fix`: Bug fix
    - `docs`: Documentation changes
    - `style`: Code style changes (formatting, missing semicolons, etc.)
    - `refactor`: Code changes that neither fix bugs nor add features
    - `perf`: Performance improvements
    - `test`: Adding or modifying tests
    - `build`: Build system or external dependency changes
    - `ci`: CI/CD configuration changes
    - `chore`: Maintenance tasks, dependency updates
    - `revert`: Reverting previous commits
    - `config`: Configuration file changes
    - `security`: Security-related fixes or improvements
- Write concise details after a blank line, wrapping at 72 characters

### Pull Request Guidelines

- Use titles which follow the [Commit Message Format](#commit-message-format) summarizing all changes to be merged

### Branching Strategy

#### Workflow

- Main branch: `nixless`
- Create new branch for all new features or complex changes
  - Use short and descriptive branch names: `fix-window-snapping`, `lsp-config`, `update-docs`
- Keep branches short-lived
- Simple fixes and typos may commit directly to `nixless`

## Security Guidelines

- **NEVER** commit sensitive data to version control
- Pin dependencies to specific versions for security-critical tools
- Use 1Password CLI for SSH agent and secrets management
- Follow least privilege principle, grant only the minimum necessary access and permissions
- Review system modification permissions carefully
- Validate permissions before script execution
- Ensure logs don't contain sensitive information
- Configure secure defaults for network-enabled tools
- Limit network access and validate all external connections
