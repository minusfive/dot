---
name: coding-guidelines
description: Coding standards and guidelines for writing, reviewing, and refactoring code across software projects.
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
- **MUST ALWAYS** validate all rules were followed after completing changes
- Handle all errors
- Validate all user inputs and system states
- Run linters, builds, and tests before making changes to understand unrelated issues
- Prefer tools from the ecosystem to automate tasks and reduce mistakes
- Use refactoring tools to automate changes
- Use linters and formatters to fix code style and correctness
- Use local variables to limit scope
- **ALWAYS** add and update type annotations

## Lua (Neovim, Hammerspoon, WezTerm, Yazi)

- Organize `---@module` references at the top of the file, sorted alphabetically
- Use explicit module returns and clear structure

## Shell Scripts (Zsh)

- Use consistent logging functions
- Use `set -euo pipefail` for error safety

## Configuration Files

- Consistent key naming conventions
- Logical grouping with fallback values
- Modular structure separating concerns
- **MUST NOT** manually edit tool-generated lock files; they are managed by their respective tools

## Markdown

- Be clear and succinct
- **MUST NOT** write redundant or duplicate content, use link references
- Use standard `[text](url)` links, not wiki-style
- Validate all reference links after changes
- **MUST NOT** create table of contents unless explicitly requested
  - If one exists, keep it synchronized with actual sections
- Analyze the whole file and suggest optimizations according to these rules
- Validate markdown files with the project's configured markdown linter when available
