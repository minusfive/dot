# macOS System Configuration Project - AI Rules and Guidelines

## Project Overview

This project is a comprehensive dotfiles configuration management system for macOS, focusing on system automation, development environment setup, and productivity tools. It includes configurations for Neovim, Hammerspoon, terminal emulators (WezTerm/Ghostty), Zsh, and development tools.

## CRITICAL SECTIONS FOR AI ASSISTANTS

**READ FIRST**: Before proceeding with any operations, review these mandatory sections:

- [PROJECT CONTEXT](#project-context) - Architecture, workflow, tools
- [SECURITY](#mandatory-security) - Credential management, permissions, maintenance
- [CRITICAL INTERACTION RULES](#critical-interaction-rules) - Operation rejection handling, visual policy, task planning
- [IMPLEMENTATION STANDARDS](#mandatory-implementation-standards) - Code generation, commits, testing, integration

## Project Context

### Project Structure

```sh
dot/                              # macOS dotfiles configuration system
├── .stow-local-ignore            # Stow ignore patterns
├── .stowrc                       # Stow configuration
├── AGENTS.md                     # AI agent rules and guidelines
├── README.md                     # Project documentation
├── biome.json                    # Code formatter configuration
├── compose.yaml                  # Docker services
├── mise.toml                     # Project tool versions
├── otel-collector-config.yaml    # OpenTelemetry collector configuration
│
├── assets/                       # Project assets (wallpaper, screenshots)
├── scripts/                      # Setup automation scripts (Zsh)
│   ├── init.zsh                  # Bootstrap entry point
│   ├── functions.zsh             # Utility functions
│   ├── brew.zsh                  # Package management
│   ├── symlink.zsh               # Dotfile deployment
│   ├── mise.zsh                  # Tool version management
│   ├── betterdisplay.zsh         # Display management
│   ├── os.zsh                    # System configuration
│   ├── vm.zsh                    # Virtualization setup
│   └── zsh.zsh                   # Shell configuration
│
├── tests/                        # Testing framework
│   ├── nvim/repro.lua            # Neovim test environment
│   └── scripts/                  # Script test suite
│
└── .config/                      # XDG configuration directory
    ├── nvim/                     # Neovim editor
    ├── hammerspoon/              # macOS automation
    ├── wezterm/                  # Terminal emulator
    ├── ghostty/                  # Alternative terminal
    ├── yazi/                     # File manager
    ├── zellij/                   # Terminal multiplexer
    ├── tmux/                     # Terminal multiplexer
    ├── git/                      # Version control
    ├── lazygit/                  # Git interface
    ├── zsh/                      # Shell customization
    ├── brew/                     # Package declarations
    ├── mise/                     # Tool management
    ├── bat/                      # Syntax highlighting
    ├── btop/                     # System monitoring
    ├── BetterDisplay/            # Display management
    ├── 1Password/                # Security integration
    ├── fzf/                      # Fuzzy finder
    ├── harper/                   # Spell checking
    ├── colortail/                # Log colorization
    ├── delta/                    # Git diff viewer
    ├── fd/                       # File finder
    ├── github-copilot/           # AI coding assistant
    └── mcphub/                   # Development server
```

### Architecture Overview

#### Core Setup System

- **Bootstrap Script**: Main entry point via setup scripts
- **Package Management**: Homebrew with Brewfile (`.config/brew/Brewfile`) for declarative package management
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
- `os.zsh`: System-specific configuration
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

#### Tool Version and Environment Management

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
- `ripgrep`: Fast text search (configured via command-line options)
- `zellij`: Terminal multiplexer alternative to tmux
- `1Password`: SSH agent integration
- `harper`: Spell checking and dictionary management

#### Display Management

- **BetterDisplay** (`.config/BetterDisplay/`): Display utility configuration
  - `config.plist`: Main settings export/import file
  - `README.md`: Configuration documentation and troubleshooting
  - Automated backup system for settings before imports
  - Cross-system compatibility guidance for display-specific settings

### Project Development Workflow

#### Setup Process

1. **Initial Setup**: Run bootstrap script with profile selection
1. **Package Installation**: Homebrew manages system and development tools
1. **Symlink Creation**: GNU Stow creates symlinks to configuration files
1. **Tool Installation**: mise manages development tool versions
1. **Shell Configuration**: Zsh with custom functions and completion

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

### MANDATORY: Project Analysis and Context Understanding

#### System Configuration Context

You are an expert in:

- System configuration and automation
- Neovim configuration and plugin management
- Hammerspoon automation and window management
- Terminal emulator configuration (WezTerm, Ghostty)
- Zsh scripting and shell customization
- Lua scripting for configuration files
- Dotfiles management with GNU Stow
- Development tooling and workflow optimization
- Container orchestration and virtualization (Lima, Podman, Docker)

When analyzing this project:

1. **Understand Context**: Consider the macOS-centric nature and development focus
1. **Respect Structure**: Maintain the established organization patterns
1. **Follow Standards**: Adhere to the documented coding standards
1. **Test Recommendations**: Suggest testable and reversible changes
1. **Document Changes**: Explain rationale for suggested modifications

### MANDATORY: User Interaction and Specialized Knowledge

#### Essential Interaction Patterns

1. **Incremental Changes**: Suggest small, testable modifications
1. **Confirmation Requests**: Always ask before making potentially destructive changes
1. **Progress Communication**: Keep user informed of multi-step operations
1. **Configuration Explanation**: Explain complex configuration decisions

#### Specialized Knowledge Areas

AI agents MUST leverage expertise in:

- **System Integration**: Understanding system-level configurations and their interactions
- **Development Workflow Optimization**: Suggesting improvements that enhance productivity
- **Tool Ecosystem Harmony**: Ensuring new additions complement existing tools
- **Configuration Maintenance**: Helping maintain long-term system stability and performance

#### Reference Implementation

- **Error Handling**: Follow patterns in `scripts/functions.zsh` logging system
- **User Prompts**: Use patterns from `scripts/betterdisplay.zsh` for interactive decisions
- **Testing Integration**: Reference comprehensive patterns in `tests/scripts/` directory

## CRITICAL Interaction Rules

### MANDATORY: Operation Rejection Handling

**HIGHEST PRIORITY RULE**: When any tool operation, file edit, or command execution is rejected, declined, or fails:

1. **IMMEDIATELY STOP** the current approach
1. **ASK FOR EXPLANATION**: "I see that operation was rejected. Could you help me understand why?"
1. **REQUEST GUIDANCE**: "What would you prefer I do instead?"
1. **WAIT FOR INSTRUCTIONS**: Do not attempt alternative approaches without explicit user direction
1. **ACKNOWLEDGE CONSTRAINTS**: Respect user preferences and system limitations

#### Examples of Rejection Scenarios

- **File Edit Rejected**: User cancels/exits editor - Ask what changes they want instead
- **Command Fails**: Tool returns error - Ask how to proceed or what alternative to try
- **User Says "No"**: Direct rejection - Ask for explanation and alternative approach
- **Permission Denied**: System blocks operation - Ask for guidance on permissions or alternatives

#### Anti-Patterns (DO NOT DO)

- **Don't Retry Immediately**: Avoid trying a different approach without asking
- **Don't Assume**: Never assume you know why the operation was rejected
- **Don't Continue Blindly**: Avoid continuing with related operations that might also be problematic
- **Don't Generalize**: Avoid providing generic solutions without understanding the specific issue

#### Response Template

```md
I see that [specific operation] was rejected/failed.

Could you help me understand:

1. Why this approach isn't suitable?
1. What you'd prefer I do instead?
1. Are there any constraints I should be aware of?

I'll wait for your guidance before proceeding.
```

### MANDATORY: Visual Elements Policy

**NO EMOJIS OR ICONS**: Do not use emojis, Unicode symbols, or decorative icons in responses or generated code unless explicitly requested. Keep all communication clean and text-based.

### MANDATORY: Task Planning and Execution Protocol

**REQUIRED FOR ALL TASKS**: Every task must begin with a clear execution plan before any implementation begins.

#### Planning Requirements and Standards

1. **Initial Plan Presentation**: Always start by presenting a markdown checklist of all required steps
1. **Step-by-Step Execution**: Complete each step in the plan sequentially
1. **Progress Tracking**: After completing each step, present the updated checklist with completed items marked
1. **Plan Adaptation**: If steps need modification during execution, update the plan and explain changes
1. **Comprehensive Planning**: Include all necessary steps from analysis to verification
1. **Granular Steps**: Break complex operations into discrete, manageable actions
1. **Clear Descriptions**: Each step should be understandable and actionable
1. **Logical Sequence**: Order steps in the most efficient and safe execution order
1. **Dependency Awareness**: Ensure each step builds appropriately on previous steps

##### Required Format

Use this exact format for task plans:

```markdown
### Task Plan

- [ ] Step 1: Brief description of first action
- [ ] Step 2: Brief description of second action
- [ ] Step 3: Brief description of third action
- [ ] Step 4: Brief description of final action
```

##### Progress Updates

After completing each step, show the updated plan:

```markdown
### Task Plan

- [x] Step 1: Brief description of first action
- [ ] Step 2: Brief description of second action
- [ ] Step 3: Brief description of third action
- [ ] Step 4: Brief description of final action
```

## MANDATORY: Implementation Standards

### Code Generation and Style Guidelines

#### Generation Standards

- **File Path Comments**: Include `// filepath: path/to/file` in code blocks
- **Existing Code Preservation**: Use `// ...existing code...` to indicate unchanged sections
- **Language Specificity**: Use appropriate language identifiers in code blocks
- **Error Handling**: Include robust error handling in generated scripts
- **Test Coverage**: When adding new scripts, include corresponding tests in `tests/scripts/`

#### Style Standards

- **Indentation**: 2 spaces for most configuration files
- **Language Conventions**: Follow each tool's recommended practices
- **Documentation**: Comprehensive comments for complex configurations
- **Modularity**: Keep configurations organized and easily maintainable
- **XDG Compliance**: Use XDG Base Directory specification where possible
- **Functional Over OOP**: Prefer functional programming patterns

### Language-Specific Standards

#### Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- **Local Variables**: Use local variables where appropriate
- **Module Structure**: Prefer explicit returns and clear module structure
- **Documentation**: Document complex functions with LuaDoc-style comments
- **Lazy Loading**: Follow lazy loading patterns for Neovim plugins
- **Type Annotations**: Find or generate appropriate type annotations

#### Shell Scripts (Zsh)

- **Error Handling**: Use `set -euo pipefail` for error handling
- **Logging Functions**: Implement logging functions with consistent formatting
- **Function Scope**: Use immediately invoked functions for scope isolation
- **Variable Naming**: Prefix internal variables with double underscores

#### Configuration Files

- **TOML Usage**: Use TOML for structured configuration where supported
- **Key Naming**: Maintain consistent key naming conventions
- **Logical Grouping**: Group related configurations logically
- **Fallback Values**: Include fallback/default values where appropriate
- **Modular Structure**: Separate concerns into focused configuration files
- **Version Control**: Track all configuration changes with meaningful commits
- **Documentation**: Comment complex configurations and decision rationale

#### Markdown Documentation

- **Use Proper Headings**: Replace `**Title**:` pseudo-titles with markdown headings (`###`, `####`, etc.)
- **Maintain Heading Hierarchy**: Follow logical levels without skipping (H1 → H2 → H3 → H4)
- **Bold Text for Emphasis Only**: Reserve bold formatting for emphasis within content, not section headers
- **Standard Link Format**: Use `[text](url)` format instead of wiki-style `[[text]]` links
- **Consistent List Formatting**:
  - Use `-` (hyphens) for all unordered list items
  - Use `1.` for all ordered list items instead of explicit numbering (`1.`, `2.`, `3.`, etc.)
  - Include blank lines before and after list groups
  - Use 2-space indentation for sub-items in nested lists

### Testing and Validation Standards

#### Testing Protocols

- **Neovim Testing**: Use `tests/nvim/repro.lua` for isolated testing
- **Script Testing**: Comprehensive test suite in `tests/scripts/`
- **Configuration Validation**: Test changes in isolated environments
- **Version Control**: Git-based backup and rollback capability

#### Validation Standards

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
1. **Different Change Types**: Bug fixes vs. new features
1. **Independent Concerns**: Changes that can be reviewed independently

**Keep in Single Commit When**:

1. **Tightly Coupled Changes**: Implementation and its tests
1. **Atomic Operations**: Feature requiring changes across multiple files
1. **Small Related Changes**: Minor formatting fixes across similar files

#### Git Workflow Tools

- Use `git add -p` for interactive staging
- Leverage `git rebase -i` to reorganize commits
- Consider `git commit --fixup` for small corrections
- Use meaningful branch names reflecting change scope

#### Reference Integrity Management

**MANDATORY**: When making changes that affect references, always validate and update all related links:

**Heading Changes**:

1. **Update Internal Links**: When modifying headings, update all internal markdown references
1. **Fragment ID Rules**: Follow standard markdown fragment generation (lowercase, hyphens for spaces, remove special characters)
1. **Cross-Reference Validation**: Verify all `[text](#fragment)` links point to existing headings
1. **Documentation Updates**: Update any external documentation that references changed headings

**File Structure Changes**:

1. **Path Reference Updates**: When moving/renaming files, update all path references in documentation
1. **Symlink Validation**: Verify GNU Stow symlinks remain valid after file restructuring
1. **Script Path Updates**: Update any hardcoded paths in setup scripts and configuration files
1. **Test Reference Updates**: Ensure test files reference correct paths and configurations

**Validation Protocol**:

1. **Pre-Commit Check**: Validate all references before committing changes
1. **Automated Validation**: Use tools to verify link integrity when possible
1. **Documentation Review**: Include reference validation in code review process
1. **Reference Audit**: Periodically audit all internal and external references for accuracy

### Security Considerations

**Before implementing any changes, review the [SECURITY](#mandatory-security) section for:**

- **Credential Management**: Ensure no sensitive data is committed
- **Permission Management**: Validate script and configuration permissions
- **Configuration Security**: Review security implications of configuration changes
- **Monitoring and Auditing**: Document changes for security auditing purposes

## MANDATORY: Security

### Credential Management

- **1Password Integration**: Use 1Password for secure credential storage and SSH agent integration
- **API Key Management**: Store API keys and tokens securely using 1Password CLI or environment variables
- **SSH Key Security**: Leverage 1Password SSH agent for secure key management
- **Credential Rotation**: Regularly rotate credentials and API keys
- **Access Scoping**: Limit credential scope to minimum required permissions

### Permission Management

- **Principle of Least Privilege**: Grant only necessary permissions for each tool and configuration
- **System-Level Access**: Carefully review system modification permissions
- **Script Execution**: Validate script permissions before execution
- **File System Access**: Limit configuration file access to appropriate users and groups
- **Network Permissions**: Monitor and control network access for development tools

### Update and Maintenance Security

- **Security Updates**: Track and apply security updates for managed tools promptly
- **Dependency Scanning**: Monitor dependencies for known vulnerabilities
- **Configuration Auditing**: Regular review of configuration security implications
- **Backup Security**: Ensure backup strategies maintain confidentiality and integrity
- **Version Pinning**: Use specific versions for security-critical tools

### Configuration Security

- **Sensitive Data Handling**: Never commit sensitive data to version control
- **Environment Variables**: Use secure environment variable management
- **Log Sanitization**: Ensure logs don't contain sensitive information
- **Network Security**: Configure secure defaults for network-enabled tools
- **Encryption**: Use encryption for sensitive configuration data where possible

### Monitoring and Auditing

- **Access Logging**: Monitor access to sensitive configuration files
- **Change Tracking**: Audit configuration changes and their sources
- **Security Scanning**: Regular security scans of the development environment
- **Incident Response**: Defined procedures for security incidents
- **Compliance Validation**: Regular validation of security compliance requirements

### Script Integration Requirements

When adding new setup scripts:

1. **Bootstrap Integration**: Add new options to `init.zsh` with appropriate flags
1. **Help System Integration**: Update `functions.zsh` help output
1. **Follow Established Patterns**: Use logging functions from existing scripts
1. **Test Integration**: Add comprehensive tests in `tests/scripts/`
