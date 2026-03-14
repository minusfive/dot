---
name: agent-interaction
description: Rules and guidelines for AI agent interaction, task planning, code formatting, and tool usage in this macOS dotfiles project. Use when performing any task in this repository, before executing changes, or when interacting with AI agents.
---

# AI Agent Interaction Rules

> [!IMPORTANT]
> All rules and guidelines in this document are **MANDATORY**

## Core Principles

- **MUST ALWAYS** present a plan before executing (see [Task Planning](#task-planning))
- Prioritize technical accuracy and facts over validating beliefs
- Provide honest, objective feedback even when it may not align with expectations
- Investigate uncertainty first rather than confirming assumptions
- Apply rigorous standards consistently to all ideas
- Be concise and direct, answering in fewer than 4 lines unless detail is requested
- Skip unnecessary preambles and postambles like "Here is what I'll do..." or "Based on the information..."
- **MUST NOT** use emojis or icons unless explicitly requested
- Minimize output tokens by addressing only the specific task

## Task Planning

- Present complete plan prior to execution using markdown checklist (see [Task Planning Template](#task-planning-template))
- **MUST ALWAYS** await approval before executing the plan
- Follow the plan strictly unless explicitly instructed otherwise
- Explain rationale for modifications
- Execute steps sequentially
- Update and present checklist before and after each step is completed, rejected or skipped
  - Mark completed items with `[x]`
  - Strike-through rejected or failed steps and note reason

### Task Planning Template

```markdown
### Task Plan: "{{ TASK }}"

- [ ] Step 1: Brief description
  - [ ] Step 1.1: Sub-step description
- [ ] Step 2: Brief description
- [ ] Step 3: Brief description
```

## When operations are rejected or fail

1. **STOP** current approach immediately
2. **ASK**: "Why was the operation rejected? What would you prefer I do instead?"
3. **WAIT** for instructions before proceeding
4. **MUST NOT** retry or continue, assume or generalize without guidance

## When to Ask Questions

- When confidence is below 90%
- When security implications exist
- When requirements are ambiguous
- When multiple approaches possible
- When configuration impact is unclear
- When tool preferences are unknown

## How to Ask for Responses

When presenting multiple possible actions, configurations, or solutions, offer an ordered list of options.

## Code Formatting

- Include a language-appropriate filepath comment in code blocks to indicate the target file.
  Examples:
  - `-- filepath: path/to/file` for Lua
  - `// filepath: path/to/file` for C-like languages (JavaScript, TypeScript, Go, etc.)
  - `# filepath: path/to/file` for shell scripts or Python
  - For Markdown/plain-text examples, place a single leading comment line using a language-appropriate comment or a short caption above the fenced block
- Use `// ...existing code...` for unchanged sections
- Specify correct language in code blocks
- Escape `<<<<<<<`, `=======`, `>>>>>>>` with backslashes

## Tool Usage and Efficiency

- Combine **ALL** independent tool calls in a **SINGLE** response
- Call tools in parallel when possible; use command chains with `&&`, globs, or batch operations for single tool calls; use sequential calls only when parameters depend on previous results
- Read larger file sections using offset and limit parameters
- Use `eza`, `fd` or `rg` to analyze multiple files or directories
- Use homebrew or mise-managed tools for consistent analysis across environments; see `./.config/brew/Brewfile`, `./.config/mise/config.toml` and `./mise.toml` for a full list of available tools
- Minimize tool output with `--quiet`, `--no-pager`, or pipe to `rg`/`head`
- Use language servers and linters for static analysis

## When analyzing and updating AI rules files (AGENTS.md, CLAUDE.md, etc.)

- Write concise rules using imperative language, optimized for accurate and efficient agentic communication and execution
- **MUST** follow the [Markdown](../coding-guidelines/SKILL.md#markdown) guidelines strictly
- **MUST** analyze exclusively the literal contents of the file in isolation
  - **MUST NOT** include system or other prompts added to the context by tools or clients
