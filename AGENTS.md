# macOS System Configuration Project - AI Rules and Guidelines

## Project Overview

This project is a comprehensive macOS dotfiles configuration management system, focusing on system automation, development environment setup, and productivity tools. The project includes configurations for Neovim, Hammerspoon, WezTerm/Ghostty terminals, Zsh shell, and numerous development tools.

## CRITICAL SECTIONS FOR AI ASSISTANTS

**READ FIRST**: Before proceeding with any operations, review these mandatory sections:

- [CRITICAL INTERACTION RULES](#critical-interaction-rules) - Operation rejection handling, visual policy, task planning
- [IMPLEMENTATION STANDARDS](#mandatory-implementation-standards) - Code generation, commits, testing, integration
- [PROJECT CONTEXT](#project-context) - Architecture, workflow, tools, security

## CRITICAL INTERACTION RULES

### MANDATORY: Operation Rejection Handling

**HIGHEST PRIORITY RULE**: When any tool operation, file edit, or command execution is rejected, declined, or fails:

1. **IMMEDIATELY STOP** the current approach
2. **ASK FOR EXPLANATION**: "I see that operation was rejected. Could you help me understand why?"
3. **REQUEST GUIDANCE**: "What would you prefer I do instead?"
4. **WAIT FOR INSTRUCTIONS**: Do not attempt alternative approaches without explicit user direction
5. **ACKNOWLEDGE CONSTRAINTS**: Respect user preferences and system limitations

#### Examples of Rejection Scenarios

- **File Edit Rejected**: User cancels/exits editor - Ask what changes they want instead
- **Command Fails**: Tool returns error - Ask how to proceed or what alternative to try
- **User Says "No"**: Direct rejection - Ask for explanation and alternative approach
- **Permission Denied**: System blocks operation - Ask for guidance on permissions or alternatives

#### Anti-Patterns (DO NOT DO)

- Immediately trying a different approach without asking
- Assuming you know why the operation was rejected
- Continuing with related operations that might also be problematic
- Providing generic solutions without understanding the specific issue

#### Response Template

```md
I see that [specific operation] was rejected/failed.

Could you help me understand:

1. Why this approach isn't suitable?
2. What you'd prefer I do instead?
3. Are there any constraints I should be aware of?

I'll wait for your guidance before proceeding.
```

### MANDATORY: Visual Elements Policy

**NO EMOJIS OR ICONS**: Do not use emojis, Unicode symbols, or decorative icons in responses or generated code unless explicitly requested by the user. Keep all communication clean and text-based.

### MANDATORY: Task Planning and Execution Protocol

**REQUIRED FOR ALL TASKS**: Every task must begin with a clear execution plan before any implementation begins.

#### Task Planning Requirements

1. **Initial Plan Presentation**: Always start by presenting a markdown checklist outlining all steps required to complete the task
2. **Step-by-Step Execution**: Complete each step in the plan sequentially
3. **Progress Tracking**: After completing each step, present the updated checklist with completed items marked
4. **Plan Adaptation**: If steps need modification during execution, update the plan and explain changes

#### Plan Format Standards

Use this exact format for task plans:

```markdown
### Task Plan

- [ ] Step 1: Brief description of first action
- [ ] Step 2: Brief description of second action
- [ ] Step 3: Brief description of third action
- [ ] Step 4: Brief description of final action
```

#### Progress Update Standards

After completing each step, show the updated plan:

```markdown
### Task Plan

- [x] Step 1: Brief description of first action
- [ ] Step 2: Brief description of second action
- [ ] Step 3: Brief description of third action
- [ ] Step 4: Brief description of final action
```

#### Implementation Guidelines

1. **Comprehensive Planning**: Include all necessary steps from analysis to verification
2. **Granular Steps**: Break complex operations into discrete, manageable actions
3. **Clear Descriptions**: Each step should be understandable and actionable
4. **Logical Sequence**: Order steps in the most efficient and safe execution order
5. **Dependency Awareness**: Ensure each step builds appropriately on previous steps

## MANDATORY: Implementation Standards

### Code Generation and Development Standards

#### Code Generation Guidelines

- **File Path Comments**: Include `// filepath: path/to/file` in code blocks
- **Existing Code Preservation**: Use `// ...existing code...` to indicate unchanged sections
- **Language Specificity**: Use appropriate language identifiers in code blocks
- **Error Handling**: Include robust error handling in generated scripts
- **Test Coverage**: When adding new scripts, include corresponding tests in `tests/scripts/`

#### General Code Style Guidelines

- **Indentation**: 2 spaces for most configuration files
- **Language Conventions**: Follow each tool's recommended practices
- **Documentation**: Comprehensive comments for complex configurations
- **Modularity**: Keep configurations organized and easily maintainable
- **XDG Compliance**: Use XDG Base Directory specification where possible

#### Configuration Best Practices

- **Modular Structure**: Separate concerns into focused configuration files
- **Version Control**: Track all configuration changes with meaningful commits
- **Documentation**: Comment complex configurations and decision rationale

### Language-Specific Standards

#### Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- Use local variables where appropriate
- Prefer explicit returns and clear module structure
- Document complex functions with LuaDoc-style comments
- Follow lazy loading patterns for Neovim plugins

#### Shell Scripts (Zsh)

- Use `set -euo pipefail` for error handling
- Implement logging functions with consistent formatting
- Use immediately invoked functions for scope isolation
- Prefix internal variables with double underscores

#### Configuration Files

- Use TOML for structured configuration where supported
- Maintain consistent key naming conventions
- Group related configurations logically
- Include fallback/default values where appropriate

#### Markdown Documentation

- **Use Proper Headings**: Replace `**Title**:` pseudo-titles with markdown headings (`###`, `####`, etc.)
- **Maintain Heading Hierarchy**: Follow logical levels without skipping (H1 → H2 → H3 → H4)
- **Bold Text for Emphasis Only**: Reserve bold formatting for emphasis within content, not section headers
- **Standard Link Format**: Always use standard markdown link format `[text](url)` instead of wiki-style `[[text]]` links

### Testing and Validation Standards

#### Testing Protocols

- **Neovim Testing**: Use `tests/nvim/repro.lua` for isolated testing
- **Script Testing**: Comprehensive test suite in `tests/scripts/`
- **Configuration Validation**: Test changes in isolated environments
- **Version Control**: Git-based backup and rollback capability

#### Validation Requirements

- **Regular Updates**: Keep tools and configurations current
- **Testing Protocol**: Validate changes before deployment
- **Rollback Plan**: Maintain ability to revert problematic changes
- **Performance Monitoring**: Track configuration impact on system performance

### Change Management Protocol

#### Commit Standards

- **Conventional Commits**: Use format `<type>[optional scope]: <description>`
- **Common Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Examples**:
  - `feat(nvim): add new plugin configuration`
  - `fix(zsh): resolve completion loading issue`
  - `docs(README): update installation instructions`

#### Commit Separation Rules

**Create Separate Commits When**:

1. **Different Functional Areas**: E.g.: Neovim vs. Hammerspoon changes
2. **Different Change Types**: Bug fixes vs. new features
3. **Independent Concerns**: Changes that can be reviewed independently

**Keep in Single Commit When**:

1. **Tightly Coupled Changes**: Implementation and its tests
2. **Atomic Operations**: Feature requiring changes across multiple files
3. **Small Related Changes**: Minor formatting fixes across similar files

#### Git Workflow Tools

- Use `git add -p` for interactive staging
- Leverage `git rebase -i` to reorganize commits
- Consider `git commit --fixup` for small corrections
- Use meaningful branch names reflecting change scope

### Script Integration Requirements

When adding new setup scripts:

1. **Bootstrap Integration**: Add new options to `init.zsh` with appropriate flags
2. **Help System Integration**: Update `functions.zsh` help output
3. **Follow Established Patterns**: Use logging functions from existing scripts
4. **Test Integration**: Add comprehensive tests in `tests/scripts/`

## PROJECT CONTEXT

### System Configuration Context

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

### Architecture Overview

#### Core Setup System

- **Bootstrap Script**: Main entry point via setup scripts
- **Package Management**: Homebrew with Brewfile for declarative package management
- **Tool Versioning**: mise for managing development tool versions
- **Symlink Management**: GNU Stow for dotfile deployment
- **Configuration Organization**: XDG Base Directory compliant structure

#### Tool Integration Patterns

- **Shell Integration**: Common environment variables and paths
- **Theme Consistency**: Catppuccin color scheme across tools
- **Key Binding Harmony**: Consistent shortcuts across applications
- **Data Sharing**: XDG directories for configuration and cache

### Project Setup Scripts (`scripts/`)

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

- `mise.toml`: This project's specific tool versions and environment
- `.config/mise/config.toml`: Global tool versions and environment configuration

#### Git and Version Control

- `.config/git/config`: Global Git settings and aliases
- `.config/git/ignore`: Global Git ignore patterns
- `.config/lazygit/config.yml`: Lazygit (Terminal UI for Git operations) configuration

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

### Project Development Workflow

#### Setup Process

1. **Initial Setup**: Run bootstrap script with profile selection
2. **Package Installation**: Homebrew manages system and development tools
3. **Symlink Creation**: GNU Stow creates symlinks to configuration files
4. **Tool Installation**: mise manages development tool versions
5. **Shell Configuration**: Zsh with custom functions and completion

#### AI Development Integration

- **VectorCode Usage**: Semantic search and code analysis
- **Container Development**: Lima/Podman for AI services
- **Code Indexing**: Intelligent navigation and suggestions

### Project Dependencies and Requirements

#### Core Dependencies

- **macOS**: Primary target platform
- **Homebrew**: Package management foundation
- **GNU Stow**: Symlink management system
- **Zsh**: Advanced shell with completion support

#### Development Tools

- **mise**: Multi-language tool version management
- **Git**: Version control with enhanced workflows
- **Neovim**: Primary text editor with extensive plugin ecosystem
- **Lima/Podman**: Containerization and virtualization

#### Optional Enhancements

- **Hammerspoon**: macOS automation and window management
- **Terminal Emulators**: WezTerm or Ghostty with advanced features
- **File Management**: Yazi for enhanced terminal file operations
- **System Monitoring**: btop, htop for system resource monitoring
- **Display Management**: BetterDisplay for advanced display scaling and management

### Security and Maintenance

- **Credential Management**: Use 1Password for secure credential storage
- **Permission Management**: Apply principle of least privilege
- **Update Monitoring**: Track security updates for managed tools
- **Configuration Auditing**: Regular review of configuration security implications
- **Backup Strategy**: Regular backups of working configurations

### MANDATORY: Project Analysis and Context Understanding

When analyzing this project:

1. **Understand Context**: Consider the macOS-centric nature and development focus
2. **Respect Structure**: Maintain the established organization patterns
3. **Follow Standards**: Adhere to the documented coding standards
4. **Test Recommendations**: Suggest testable and reversible changes
5. **Document Changes**: Explain rationale for suggested modifications

### MANDATORY: User Interaction and Specialized Knowledge

#### Essential Interaction Patterns

1. **Incremental Changes**: Suggest small, testable modifications
2. **Confirmation Requests**: Always ask before making potentially destructive changes
3. **Progress Communication**: Keep user informed of multi-step operations
4. **Configuration Explanation**: Explain complex configuration decisions

#### Specialized Knowledge Areas

AI assistants should leverage expertise in:

- **macOS System Integration**: Understanding system-level configurations and their interactions
- **Development Workflow Optimization**: Suggesting improvements that enhance productivity
- **Tool Ecosystem Harmony**: Ensuring new additions complement existing tools
- **Configuration Maintenance**: Helping maintain long-term system stability and performance

#### Reference Implementation

- **Error Handling**: Follow patterns in `scripts/functions.zsh` logging system
- **User Prompts**: Use patterns from `scripts/betterdisplay.zsh` for interactive decisions
- **Testing Integration**: Reference comprehensive patterns in `tests/scripts/` directory
