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

1. [Agent Skills specification](https://agentskills.io/specification).
2. The active harness's public documentation for skills, instruction files, and agent/subagent definitions. Identify the active harness from environment signals (top-level instruction file headers, repository configuration, user configuration) before resolving its documentation.
3. Repository-specific instruction documentation for the active project (top-level instruction file, skill READMEs, related agent definitions).

Use the loaded specs as the active source of truth for the task. Avoid static assumptions and derive requirements dynamically from the loaded references and current repository state.

## Audit Scope

- When auditing instruction files, analyze only the file's literal contents. Exclude system- and client-injected prompt content from the analysis.
- Audit for duplicate or conflicting instructions across all repository instruction entrypoints (top-level instruction files, skills, agent/subagent definitions).
- Prefer a single canonical source and cross-reference it rather than duplicating the same guidance — this applies equally to skills, `AGENTS.md`, `CLAUDE.md`, and agent definitions.
- When multiple files could host the same policy, treat the most specific skill as canonical and have broader files cross-reference it.
- Flag or remove drift-prone duplication that can diverge from real behavior over time.

## Validation

- Validate skill metadata, structure, and behavior against the loaded specs.
- Validate and audit each skill `description` for discoverability quality, including clear invocation cues and relevant trigger keywords, and avoid "how it works" wording.
- When renaming or restructuring an instruction file or skill, search the repository for stale references and update them.
- Verify every `assets/…` (or equivalent referenced-resource) path resolves to an existing file and that the asset's current contents still match how the body cites them.
- Verify every concrete claim in the file before shipping: every command runs, every flag behaves as stated, every URL resolves, every directive or syntax example matches current tool behavior. Inherited assumptions from a source skill or older docs do not count as verified.
- Run the markdown linter required by the `coding-guidelines` skill against changed files.

## Critique

The repository's general post-validation critique gate (defined in the top-level instruction file) applies to every change. This skill adds the following instruction-file-specific checks; apply them during that critique pass rather than as a separate cycle:

- Does this rule conflict with another instruction entrypoint?
- Would a reasonable agent misread it?
- Does it over- or under-constrain compared to the user's actual intent?
- Is the canonical source still canonical after this edit?

For non-trivial rule changes (new skill, restructuring, broadened scope, renames), run a critique-capable sub-agent review before presenting the edit. Select that capability based on the active harness rather than hard-coding a tool name.

## Authoring Style

- Write concise rules using imperative language optimized for accurate and efficient agentic execution.
- Keep prose harness-agnostic and capability-based. Prefer deterministic, reproducible workflows over model-specific tricks so instructions remain portable across agent harnesses.
- Avoid naming specific models, effort levels, tools, or products in reusable instructions unless the file is intentionally tool-specific.
- Instruct agents to choose execution approach based on efficiency, cost, capability, and task requirements instead of fixed named components.
- Prefer clear, specific, and deterministic instructions that can be delegated to lower-cost but capable subagents.
- Prefer delegating concrete execution work over delegating open-ended "thinking" work to subagents.
- Follow `coding-guidelines` skill markdown guidance.
- Use markdown links (`[text](url)`) instead of bare URLs.

## Skill Authoring

This section governs how to create, edit, and structure individual skills.

### Frontmatter and metadata

- Set `name` to a kebab-case slug that matches the skill's directory name.
- Match every required frontmatter field to the Agent Skills specification loaded during intake.
- Set `user-invocable: true` when the user should be able to invoke the skill explicitly via a slash-command or equivalent harness affordance. Set it to `false` for skills meant only for model selection.
- Set `disable-model-invocation: true` only to suppress automatic selection — for skills that must run only on explicit invocation. Default to `false`.

### Scope and splitting

- Author one skill per cohesive task domain, not per file or per tool.
- Split an existing skill when its body grows long enough that an agent will not load all of it, when two clearly separate triggers share unrelated guidance, or when sections of the body apply to disjoint user intents.
- Extend an existing skill instead of creating a new one when the new guidance shares both triggers and audience with the existing skill's scope.

### Progressive disclosure

- Keep `SKILL.md` to imperative behavior and rules.
- Move reference content (templates, exemplars, lookup tables, long enumerations) into an `assets/` subdirectory and reference it by relative path from the skill body.
- Reference assets explicitly by relative path; do not assume the harness auto-loads them.

### Description discoverability

- Optimize every skill `description` for discoverability at skill-selection time.
- Prioritize searchable task cues (domains, artifacts, user intents, aliases, and common trigger phrases) over implementation details.
- Describe when to invoke the skill using concrete "use when" language and likely user wording.
- Avoid descriptions that mostly explain what the skill does internally or how it works.
- Keep descriptions concise but keyword-rich so selection systems can reliably match relevant requests.
- Keep descriptions free of links, command examples, full path enumerations, and other content that belongs in the body. The `description` is a selector, not a summary.

### Body authoring style

- Write rules as positive, imperative directives. State what to do; describe the desired end state. Reserve "do not X" or "X is wrong" framings for cases where the antipattern is concrete, plausible, high-risk, and not already excluded by a positive rule — instruction-file authoring contains several such antipatterns (e.g., assuming the harness auto-loads referenced assets, restating canonical rules in multiple entrypoints), so negative framings appear in this skill where the exception is met.
- Negative rules carry two costs: they plant the antipattern in agent context (which can prompt the very behavior they forbid), and they can conflict with project-specific configuration (aliases, custom directories, custom commands) that legitimately uses the named token.
- Defer to upstream documentation as the durable source of truth. When the underlying system supports configuration (custom paths, directories, env names, command aliases), reference the docs and the project's configuration; do not enumerate defaults inline as if they were invariant.
- Keep guidance language-, tool-, and version-agnostic where possible. State the rule generically and use language-specific or version-specific names only as examples, not as the rule itself.
- Prefer linking to canonical documentation over restating it; restated facts drift, links do not (and broken links are caught by validation).

## AGENTS.md Authoring

This section governs how to create, edit, and structure `AGENTS.md` files.

### Authoring behavior

- Keep `AGENTS.md` to rules that apply to all agents and all tasks, regardless of domain, language, or workflow, plus a skill index. Anything narrower belongs in a skill.
- Extract domain-, language-, or workflow-specific guidance into skills and reference them from the index.
- Update the index in the same change that adds, renames, or removes a skill.
- Pair every `AGENTS.md` with a `CLAUDE.md` at the same path whose entire contents are the literal string `@AGENTS.md` (and nothing else). Create, move, rename, and delete them in lockstep. This ensures Claude resolves to the same canonical entrypoint as other harnesses.

### Required Skills section content

- Use [`assets/agents-md-index-section.template.md`](assets/agents-md-index-section.template.md) as the canonical template for the `AGENTS.md` Skills section. Mirror its preamble verbatim, adapting only the skills-location reference to the active harness.
- Populate the index from the actual skill directory: one entry per skill, using the skill's frontmatter `name` and a one-line summary derived from its `description`.
