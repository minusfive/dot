---
name: agent-instructions-authoring
description: Use when creating, editing, auditing, or restructuring agent instruction entrypoints (`SKILL.md`, `AGENTS.md`, `CLAUDE.md`, subagent/agent definitions). Consolidate duplicate or conflicting rules, improve skill description discoverability, and validate metadata, assets, and cross-file consistency.
---

# Agent Instructions Authoring

Use this skill for any task that creates, edits, audits, or restructures files that instruct agent behavior. This includes skills (`SKILL.md`), top-level instruction files (`AGENTS.md`, `CLAUDE.md`, repo-level agent docs), subagent and agent definitions, and any other rule/instruction entry point.

Required upstream references are listed alongside the work they govern: see [Skill Authoring](#skill-authoring) for skill schema/structure references and [AGENTS.md Authoring](#agentsmd-authoring) for top-level instruction-file references. Load them when the task scope warrants; for small edits (description rewrites, wording tweaks, index updates, typo fixes), skip the load.

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
- Verify every concrete claim in the file before shipping: every command runs, every flag behaves as stated, every URL resolves, every directive, or syntax example matches current tool behavior. Inherited assumptions from a source skill or older docs do not count as verified.
- For non-trivial skill behavior edits, run a lightweight eval loop following [Evaluating skill output quality](https://agentskills.io/skill-creation/evaluating-skills): compare baseline vs updated behavior, grade assertions with evidence, and inspect pass-rate plus time/token deltas.
- For description-focused edits, follow [Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions): use should-trigger and should-not-trigger query sets, run multiple trials, and prefer train/validation splits over single-set tuning.
- Run linters following the `linting` skill.
- For changes that touch the `AGENTS.md` skill index or any skill directory under `.agents/skills/`, run `mise run lint-skills-index` to verify the index and on-disk skills stay in sync.

## Critique

The repository's general post-validation critique gate (defined in the top-level instruction file) applies to every change. This skill adds the following instruction-file-specific checks; apply them during that critique pass rather than as a separate cycle:

- Does this rule conflict with another instruction entry point?
- Would a reasonable agent misread it?
- Does it over- or under-constrain compared to the user's actual intent?
- Is the canonical source still canonical after this edit?
- Does any rule contain authoring meta-commentary that belongs in the authoring skill?

## Authoring Style

- Write concise rules using imperative language optimized for accurate and efficient agentic execution.
- Keep prose harness-agnostic and capability-based. Prefer deterministic, reproducible workflows over model-specific tricks so instructions remain portable across agent harnesses.
- Avoid naming specific models, effort levels, tools, or products in reusable instructions unless the file is intentionally tool-specific.
- Instruct agents to choose execution approach based on efficiency, cost, capability, and task requirements instead of fixed named components.
- Prefer clear, specific, and deterministic instructions that can be delegated to lower-cost but capable subagents.
- Prefer delegating concrete execution work over delegating open-ended "thinking" work to subagents.
- Ground guidance in observed project reality and concrete failure modes (not generic "best practices"), per [Best practices for skill creators](https://agentskills.io/skill-creation/best-practices).
- Keep high-value "gotchas" in the always-loaded body when they prevent common, costly mistakes; move bulky reference material to assets for progressive disclosure.
- Follow `coding-guidelines` skill Markdown guidance.
- Use Markdown links (`[text](url)`) instead of bare URLs.
- Keep behavioral guidance and authoring meta-commentary separate. Behavioral rules tell executing agents what to do; meta-commentary (labels like "this is the canonical X", directives about how other files should reference the rule, taxonomy notes, audience asides) tells skill authors how to treat the rule. Meta-commentary belongs in the authoring skill (`agent-instructions-authoring`), not embedded in the behavioral rule itself.
- When a skill has critique findings that apply only to its own domain, place them in a `## Critique` section that defers to the top-level critique gate and lists only the domain-specific checks. Do not restate the gate itself, and do not push domain-specific findings up into top-level instruction files (e.g., `AGENTS.md`).

## Skill Authoring

This section governs how to create, edit, and structure individual skills.

### Required references for skill structural changes

When creating a new skill, renaming a skill, or changing frontmatter or directory structure, load these references before editing:

- [Agent Skills specification](https://agentskills.io/specification) — canonical `SKILL.md` frontmatter schema, directory layout, and loading model.
- Harness-specific skills documentation for each known conformant harness:
  - **Claude Code** — [Skills](https://code.claude.com/docs/en/skills)
  - **OpenCode** — [Skills](https://opencode.ai/docs/skills/)
  - **GitHub Copilot CLI** — [Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)

Compare each harness's frontmatter schema against the Agent Skills specification. Identify which fields are shared across harnesses, which are harness-specific extensions, and where any structural deviations exist.

When a harness requires a structural deviation that cannot be expressed within the `SKILL.md` format, surface the conflict to the user and present ordered alternatives — a harness-specific companion file or accepting a capability gap on that harness.

Use the loaded specs as the active source of truth; derive requirements dynamically from the references and current repository state rather than static assumptions. For description rewrites, body wording changes, or other non-structural edits, skip the load.

### Frontmatter and metadata

- Set `name` to a kebab-case slug that matches the skill's directory name.
- Match every required frontmatter field to the Agent Skills specification; prefer spec fields over harness-specific extensions.
- The fields `name`, `description`, `license`, and `allowed-tools` are recognized across all known conformant harnesses. The optional spec fields `compatibility` and `metadata` are spec-defined but not documented by all harnesses — include them when useful and accept that they may be ignored.
- Harness-specific fields (e.g., Claude Code's `user-invocable`, `disable-model-invocation`) are additive — include them only when intentionally targeting that harness feature, and accept that other conformant harnesses will ignore them.

### Scope and splitting

- Author one skill per cohesive task domain, not per file or per tool.
- Split an existing skill when its body grows long enough that an agent will not load all of it, when two clearly separate triggers share unrelated guidance, or when sections of the body apply to disjoint user intents.
- Extend an existing skill instead of creating a new one when the new guidance shares both triggers and audience with the existing skill's scope.

### Progressive disclosure

- Keep `SKILL.md` to imperative behavior and rules.
- Move reference content (templates, exemplars, lookup tables, long enumerations) into an `assets/` subdirectory and reference it by relative path from the skill body.
- Reference assets explicitly by relative path; do not assume the harness autoloads them.

### Description discoverability

- Optimize every skill `description` for discoverability at skill-selection time.
- Prioritize searchable task cues (domains, artifacts, user intents, aliases, and common trigger phrases) over implementation details.
- Describe when to invoke the skill using concrete "use when" language and likely user wording.
- Avoid descriptions that mostly explain what the skill does internally or how it works.
- Keep descriptions concise but keyword-rich so selection systems can reliably match relevant requests — some harnesses use keyword matching, others use semantic selection; concrete task cues work for both.
- Keep descriptions free of links, command examples, full path enumerations, and other content that belongs in the body. The `description` is a selector, not a summary.
- Keep `description` length within the specification limit and validate trigger behavior using the workflow in [Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions).

### Scripts in skills

- When adding or modifying scripts referenced by a skill, follow [Using scripts in skills](https://agentskills.io/skill-creation/using-scripts).
- Prefer one-off commands only for simple, stable invocations; move repeated or complex command logic into versioned scripts under `scripts/`.
- Require non-interactive script interfaces (flags/env/stdin), explicit `--help` usage docs, clear actionable errors, structured stdout for machine-readable results, and diagnostics on stderr.
- Require predictable exit-code behavior and safe defaults (`--dry-run`, explicit confirmation flags) for stateful or destructive operations.
- State runtime prerequisites and version expectations explicitly in skill instructions when script behavior depends on them.

### Body authoring style

- Write rules as positive, imperative directives. State what to do; describe the desired end state. Reserve "do not X" or "X is wrong" framings for cases where the antipattern is concrete, plausible, high-risk, and not already excluded by a positive rule — instruction-file authoring contains several such antipatterns (e.g., assuming the harness auto-loads referenced assets, restating canonical rules in multiple entrypoints), so negative framings appear in this skill where the exception is met.
- Negative rules carry two costs: they plant the anti-pattern in agent context (which can prompt the very behavior they forbid), and they can conflict with project-specific configuration (aliases, custom directories, custom commands) that legitimately uses the named token.
- Defer to upstream documentation as the durable source of truth. When the underlying system supports configuration (custom paths, directories, environment names, command aliases), reference the docs and the project's configuration; do not enumerate defaults inline as if they were invariant.
- Keep guidance language-, tool-, and version-agnostic where possible. State the rule generically and use language-specific or version-specific names only as examples, not as the rule itself.
- Prefer linking to canonical documentation over restating it; restated facts drift, links do not (and broken links are caught by validation).

## AGENTS.md Authoring

This section governs how to create, edit, and structure `AGENTS.md` files.

### Required references for AGENTS.md structural changes

When creating, restructuring, or pairing `AGENTS.md` with harness-specific instruction files, load these references before editing:

- **Claude Code** — [Memory & CLAUDE.md](https://code.claude.com/docs/en/memory)
- **OpenCode** — [Rules](https://opencode.ai/docs/rules/)

For small edits (rule wording tweaks, single-entry index updates), skip the load.

### Authoring behavior

- Keep `AGENTS.md` to rules that apply to all agents and all tasks, regardless of domain, language, or workflow, plus a skill index. Anything narrower belongs in a skill.
- Extract domain-, language-, or workflow-specific guidance into skills and reference them from the index.
- Update the index in the same change that adds, renames, or removes a skill.
- Pair every `AGENTS.md` with a `CLAUDE.md` at the same path whose entire contents are the literal string `@AGENTS.md` (and nothing else). Create, move, rename, and delete them in lockstep. This ensures Claude resolves to the same canonical entry point as other harnesses.

### Required Skills section content

- Use [`assets/agents-md-index-section.template.md`](assets/agents-md-index-section.template.md) as the canonical template for the `AGENTS.md` Skills section. Mirror its preamble verbatim, adapting only the skills-location reference to the active harness.
- Populate the index from the actual skill directory: one entry per skill, using the skill's frontmatter `name` and a one-line summary derived from its `description`.
