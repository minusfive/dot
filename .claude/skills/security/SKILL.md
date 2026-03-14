---
name: security
description: Security guidelines for the macOS dotfiles project covering secrets management, permissions, network access, and secure defaults. Use when making changes involving security-sensitive operations, credentials, or system permissions.
---

# Security Guidelines

- **NEVER** commit sensitive data to version control
- Pin dependencies to specific versions for security-critical tools
- Use 1Password CLI for SSH agent and secrets management
- Follow least privilege principle, grant only the minimum necessary access and permissions
- Review system modification permissions carefully
- Validate permissions before script execution
- Ensure logs don't contain sensitive information
- Configure secure defaults for network-enabled tools
- Limit network access and validate all external connections
