---
name: agent-instructions-authoring
description: Author, audit, and modify agent instructions and rule entrypoints — skills, AGENTS.md, CLAUDE.md, subagent/agent definitions, and any other file that instructs agent behavior. Use when creating, editing, renaming, or reviewing such files; when consolidating duplicated rules across them; or when validating skill metadata, discoverability, and structure.
user-invocable: true
disable-model-invocation: false
---

# Agent Instructions Authoring

Use this skill for any task that creates, edits, audits, or restructures files that instruct agent behavior. This includes skills (`SKILL.md`), top-level instruction files (`AGENTS.md`, `CLAUDE.md`, repo-level agent docs), subagent and agent definitions, and any other rule/instruction entrypoint.

## Mandatory Spec Intake

At the start of each task, load these references in this exact order:

1. [Agent Skills specification](https://agentskills.io/specification)
2. The current harness documentation for skill, instruction, and agent-definition behavior and metadata.
3. Repository-specific instruction documentation for the active project (top-level instruction file, skill READMEs, related agent definitions).

Use the loaded specs as the active source of truth for the task. Avoid static assumptions and derive requirements dynamically from the loaded references and current repository state.

## Audit Scope

- When auditing instruction files, analyze only the file's literal contents. Exclude system- and client-injected prompt content from the analysis.
- Audit for duplicate or conflicting instructions across all repository instruction entrypoints (top-level instruction files, skills, agent/subagent definitions).
- Prefer a single canonical source and cross-reference it rather than duplicating the same guidance — this applies equally to skills, `AGENTS.md`, `CLAUDE.md`, and agent definitions.
- For planning-phase completeness policy, use `planning` as canonical and keep related files as references.
- Flag or remove drift-prone duplication that can diverge from real behavior over time.

## Authoring Style

- Write concise rules using imperative language optimized for accurate and efficient agentic execution.
- Keep prose harness-agnostic and capability-based. Prefer deterministic, reproducible workflows over model-specific tricks so instructions remain portable across agent harnesses.
- Avoid naming specific models, effort levels, tools, or products in reusable instructions unless the file is intentionally tool-specific.
- Instruct agents to choose execution approach based on efficiency, cost, capability, and task requirements instead of fixed named components.
- Prefer clear, specific, and deterministic instructions that can be delegated to lower-cost but capable subagents.
- Prefer delegating concrete execution work over delegating open-ended "thinking" work to subagents.
- Follow `coding-guidelines` skill markdown guidance.
- Use markdown links (`[text](url)`) instead of bare URLs so files pass markdownlint (`MD034/no-bare-urls`).

## Validation

- Validate skill metadata, structure, and behavior against the loaded specs.
- Validate and audit each skill `description` for discoverability quality, including clear invocation cues and relevant trigger keywords, and avoid "how it works" wording.
- When renaming or restructuring an instruction file or skill, grep the repository for stale references and update them.
- Run the configured markdown linter against changed files.

## Critique

- Treat critique and validation as separate gates: validation confirms the file parses, lints, and matches the spec; critique confirms the rule is the right rule. Both must pass.
- Before finalizing a change to an instruction entrypoint, critique it: does this rule conflict with another entrypoint? Would a reasonable agent misread it? Does it over- or under-constrain compared to the user's actual intent? Is the canonical source still canonical after this edit?
- For non-trivial rule changes (new skill, restructuring, broadened scope, renames), run a critique-capable sub-agent review before presenting the edit. Do not hard-code a single tool name; choose a capability appropriate to the active harness.
- Record how critique feedback changed the edit before presenting it.

## Skill Description Authoring

- Optimize every skill `description` for discoverability at skill-selection time.
- Prioritize searchable task cues (domains, artifacts, user intents, aliases, and common trigger phrases) over implementation details.
- Describe when to invoke the skill using concrete "use when" language and likely user wording.
- Avoid descriptions that mostly explain what the skill does internally or how it works.
- Keep descriptions concise but keyword-rich so selection systems can reliably match relevant requests.
