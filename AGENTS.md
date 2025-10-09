# macOS System Configuration Project - AI Rules and Guidelines

## Project Overview

This project is a comprehensive dotfiles configuration management system for macOS, focusing on system automation, development environment setup, and productivity tools. It includes configurations for Neovim, Hammerspoon, terminal emulators (WezTerm/Ghostty), Zsh, and development tools.

## CRITICAL Sections for AI Assistants

**READ FIRST**: Before proceeding with any operations, review these mandatory sections:

- [MANDATORY: Interaction Rules](#mandatory-interaction-rules) - Operation rejection handling, visual policy, task planning
- [MANDATORY: Security](#mandatory-security) - Credential management, permissions, maintenance
- [MANDATORY: Implementation Standards](#mandatory-implementation-standards) - Code generation, commits, testing, integration
- [MANDATORY: Testing and Validation Standards](#mandatory-testing-and-validation-standards) - TDD protocol, testing requirements, validation
- [MANDATORY: Change Management Protocol](#mandatory-change-management-protocol) - Commit standards, git workflow, reference integrity
- [Project Context](PROJECT_CONTEXT.md) - Architecture, workflow, tools

## MANDATORY: Interaction Rules

### Operation Rejection Handling

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
1. **Confidence Assessment**: When confidence is below 90%, ask clarifying questions before proceeding
1. **Step-by-Step Execution**: Complete each step in the plan sequentially
1. **Progress Tracking**: After completing each step, present the updated checklist with completed items marked
1. **Plan Adaptation**: If steps need modification during execution, update the plan and explain changes
1. **Comprehensive Planning**: Include all necessary steps from analysis to verification
1. **Granular Steps**: Break complex operations into discrete, manageable actions
1. **Clear Descriptions**: Each step should be understandable and actionable
1. **Logical Sequence**: Order steps in the most efficient and safe execution order
1. **Dependency Awareness**: Ensure each step builds appropriately on previous steps

#### Clarifying Questions Protocol

Ask clarifying questions when:

- Requirements are ambiguous or incomplete
- Multiple implementation approaches are possible
- Impact on existing configurations is unclear
- User preferences for specific tools or patterns are unknown
- Security implications need validation

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
- **Edit Tool Error Prevention**: When using SEARCH/REPLACE blocks, escape any content that contains `<<<<<<<`, `=======`, or `>>>>>>>` with backslashes to prevent parser confusion
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

## MANDATORY: Testing and Validation Standards

### Test-Driven Development Protocol

**REQUIRED APPROACH**: Use TDD with acceptance tests for all implementations:

1. **Define Acceptance Criteria**: Establish clear success criteria before implementation
1. **Create Tests First**: Write tests that validate the expected behavior
1. **Implement Incrementally**: Build functionality to pass tests progressively
1. **Validate Continuously**: Run tests frequently during development
1. **Refactor Safely**: Use tests to ensure changes don't break functionality

### Testing Protocols

- **Neovim Testing**: Use `tests/nvim/repro.lua` for isolated testing
- **Script Testing**: Comprehensive test suite in `tests/scripts/`
- **Acceptance Testing**: Define and test user-visible functionality
- **Configuration Validation**: Test changes in isolated environments
- **Version Control**: Git-based backup and rollback capability

### Validation Standards

- **Test Coverage**: Ensure all new functionality has corresponding tests
- **Regular Updates**: Keep tools and configurations current
- **Testing Protocol**: Validate changes before deployment
- **Rollback Plan**: Maintain ability to revert problematic changes
- **Performance Monitoring**: Track configuration impact on system performance

## MANDATORY: Change Management Protocol

### Commit Standards

- **Conventional Commits**: Use format `<type>[optional scope]: <description>`
- **Common Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Examples**:
  - `feat(nvim): add new plugin configuration`
  - `fix(zsh): resolve completion loading issue`
  - `docs(README): update installation instructions`

### Commit Separation Rules

**Create Separate Commits When**:

1. **Different Functional Areas**: E.g.: Neovim vs. Hammerspoon changes
1. **Different Change Types**: Bug fixes vs. new features
1. **Independent Concerns**: Changes that can be reviewed independently

**Keep in Single Commit When**:

1. **Tightly Coupled Changes**: Implementation and its tests
1. **Atomic Operations**: Feature requiring changes across multiple files
1. **Small Related Changes**: Minor formatting fixes across similar files

### Git Workflow Tools

- Use `git add -p` for interactive staging
- Leverage `git rebase -i` to reorganize commits
- Consider `git commit --fixup` for small corrections
- Use meaningful branch names reflecting change scope

### Reference Integrity Management

When making changes that affect references, always validate and update all related links:

**Heading Changes**:

1. **Update Internal Links**: When modifying headings, update all internal markdown references
1. **Fragment ID Rules**: Follow standard markdown fragment generation (lowercase, hyphens for spaces, remove special characters)
1. **Cross-Reference Validation**: Verify all reference links point to existing headings
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

### Configuration Security

- **Sensitive Data Handling**: Never commit sensitive data to version control
- **Environment Variables**: Use secure environment variable management
- **Log Sanitization**: Ensure logs don't contain sensitive information
- **Network Security**: Configure secure defaults for network-enabled tools
- **Encryption**: Use encryption for sensitive configuration data where possible

### Maintenance and Monitoring

- **Security Updates**: Track and apply security updates for managed tools promptly
- **Dependency Scanning**: Monitor dependencies for known vulnerabilities
- **Configuration Auditing**: Regular review of configuration security implications
- **Backup Security**: Ensure backup strategies maintain confidentiality and integrity
- **Version Pinning**: Use specific versions for security-critical tools
- **Access Logging**: Monitor access to sensitive configuration files
- **Change Tracking**: Audit configuration changes and their sources
- **Security Scanning**: Regular security scans of the development environment
- **Incident Response**: Defined procedures for security incidents
- **Compliance Validation**: Regular validation of security compliance requirements

## Project Context and Expertise

### Core Knowledge Areas

AI agents MUST leverage expertise in:

- **System Integration**: Understanding system-level configurations and their interactions
- **Development Workflow Optimization**: Suggesting improvements that enhance productivity
- **Tool Ecosystem Harmony**: Ensuring new additions complement existing tools
- **Configuration Maintenance**: Helping maintain long-term system stability and performance

### Technology Stack

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

### Project Analysis Guidelines

When analyzing this project:

1. **Understand Context**: Consider the macOS-centric nature and development focus
1. **Respect Structure**: Maintain the established organization patterns
1. **Follow Standards**: Adhere to the documented coding standards
1. **Test Recommendations**: Suggest testable and reversible changes
1. **Document Changes**: Explain rationale for suggested modifications

### Directory Structure Analysis

**Use `eza --tree --level=n` for deep directory exploration**:

- `eza --tree --level=2 .config/` - Configuration overview
- `eza --tree --level=3 scripts/` - Script organization
- `eza --tree --level=4 .config/nvim/` - Neovim structure
- `eza --tree --all --level=2` - Include hidden files
- `eza --tree --only-dirs --level=3` - Directory structure only

Start with level 2, increase selectively for detailed analysis.

### Reference Implementation Patterns

- **Error Handling**: Follow patterns in `scripts/functions.zsh` logging system
- **User Prompts**: Use patterns from `scripts/betterdisplay.zsh` for interactive decisions
- **Testing Integration**: Reference comprehensive patterns in `tests/scripts/` directory

### Script Integration Requirements

When adding new setup scripts:

1. **Bootstrap Integration**: Add new options to `init.zsh` with appropriate flags
1. **Help System Integration**: Update `functions.zsh` help output
1. **Follow Established Patterns**: Use logging functions from existing scripts
1. **Test Integration**: Add comprehensive tests in `tests/scripts/`

### AGENTS.md Maintenance Guidelines

When updating AGENTS.md files:

1. **Concise Language**: Use clear, direct language optimized for AI comprehension
1. **Efficient Execution**: Structure guidelines to minimize decision time
1. **Eliminate Redundancy**: Consolidate overlapping sections and remove duplicate information
1. **Action-Oriented**: Focus on specific, actionable instructions rather than abstract concepts
1. **Consistent Formatting**: Maintain standard markdown structure and formatting
