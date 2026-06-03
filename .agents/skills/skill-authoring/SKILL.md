---
name: skill-authoring
description: Create, modify, audit, and validate agent skills. Use whenever skill definitions or skill behavior are being changed.
user-invocable: true
disable-model-invocation: false
---

# Skill Authoring

Use this skill for any skill manipulation task.

## Mandatory Spec Intake

At the start of each skill task, load these references in this exact order:

1. [Agent Skills specification](https://agentskills.io/specification)
2. The current harness documentation for skill behavior and metadata.
3. Repository-specific skill/instruction documentation for the active project.

Use the loaded specs as the active source of truth for the task.
Avoid static assumptions and derive requirements dynamically from the loaded references and current repository state.

## Validation and Auditing

- Validate skill metadata, structure, and behavior against the loaded specs.
- Validate and audit each skill `description` for discoverability quality, including clear invocation cues and relevant trigger keywords, and avoid "how it works" wording.
- Use markdown links (`[text](url)`) instead of bare URLs so skill docs pass markdownlint (`MD034/no-bare-urls`).
- Keep prose harness-agnostic and capability-based.
- Avoid naming specific models, effort levels, tools, or products in reusable instructions unless the skill is intentionally tool-specific.
- Instruct agents to choose execution approach based on efficiency, cost, capability, and task requirements instead of fixed named components.
- Prefer clear, specific, and deterministic instructions that can be delegated to lower-cost but capable subagents.
- Prefer delegating concrete execution work over delegating open-ended "thinking" work to subagents.
- Audit for duplicate or conflicting instructions across all repository instruction entrypoints and related skill files.
- Prefer a single canonical source and cross-reference it rather than duplicating the same guidance.
- For planning-phase completeness policy, use `planning` as canonical and keep related skills as references.
- Flag or remove drift-prone duplication that can diverge from real behavior over time.

## Skill Description Authoring

- Optimize every skill `description` for discoverability at skill-selection time.
- Prioritize searchable task cues (domains, artifacts, user intents, aliases, and common trigger phrases) over implementation details.
- Describe when to invoke the skill using concrete "use when" language and likely user wording.
- Avoid descriptions that mostly explain what the skill does internally or how it works.
- Keep descriptions concise but keyword-rich so selection systems can reliably match relevant requests.
