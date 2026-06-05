---
name: coding-guidelines
description: Apply repository coding standards for implementation and review tasks. Use when adding features, fixing bugs, refactoring, updating tests, or resolving lint/type/build issues.
---

# Coding Guidelines

## Core Coding Principles

- Explain why changes are needed before implementing
- Prefer test-driven development when practical:
  - Write acceptance tests first, implement second
  - Define acceptance criteria first
  - Implement incrementally to pass tests (Red, Green)
  - Validate continuously during development
  - Test in isolated environments
- Adhere to documented coding standards for each language or module
- **MUST NOT** delete or modify working code unless absolutely necessary
- Make minimal modifications, changing as few lines as possible
- Make surgical and precise, testable and reversible changes
- Fix only build or test failures related to your task
- Validate that changes don't break existing behavior
- Use functional patterns, avoid Object Oriented
- Maintain established organization patterns
- Organize configurations for easy maintenance
- Update only documentation directly related to your changes
- Keep existing documentation up to date
- Only add comments if they match existing style or explain complex changes
- Use existing libraries whenever possible
- Only add new libraries or update versions if absolutely necessary
- Validate that all rules were followed after completing changes
- Handle all errors
- Validate all user inputs and system states
- Run linters, builds, and tests before making changes to understand unrelated issues
- Prefer tools from the ecosystem to automate tasks and reduce mistakes
- Use refactoring tools to automate changes
- Use linters and formatters to fix code style and correctness
- Use local variables to limit scope
- Always add and update type annotations

## Critique Gate

Follow the canonical critique-before-completion gate defined in `AGENTS.md`. Apply the universal gate to every change; layer domain-specific checks on top during the same pass when relevant.

## Language-Specific Guidance

- Lua (Neovim, Hammerspoon, WezTerm, Yazi) — see the `lua` skill
- Zsh shell scripts — see the `zsh` skill
- Markdown — see the `markdown` skill

## Configuration Files

- Consistent key naming conventions
- Logical grouping with fallback values
- Modular structure separating concerns
- **MUST NOT** manually edit tool-generated lock files; they are managed by their respective tools
