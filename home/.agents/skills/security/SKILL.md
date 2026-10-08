---
name: security
description: Apply security checks for secrets, credentials, permissions, external network access, dependency risk, and sensitive configuration. Use during implementation, code review, and security review passes.
---

# Security Guidelines

- **NEVER** commit sensitive data to version control
- Pin dependencies to specific versions for security-critical tools
- Use an approved secret manager for credentials and SSH agent integration
- Follow least privilege principle, grant only the minimum necessary access and permissions
- Review system modification permissions carefully
- Validate permissions before script execution
- Ensure logs don't contain sensitive information
- Configure secure defaults for network-enabled tools
- Limit network access and validate all external connections
