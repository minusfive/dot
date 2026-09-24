---
name: agent-instructions-authoring
description: Create, update, and review skills and agent instruction files, including `AGENTS.md` and `CLAUDE.md`. Use when fixing conflicting rules, removing duplicates, or tightening writing-style enforcement.
---

# Agent Instructions Authoring

Use this skill for any task that creates, edits, audits, or restructures files that instruct agent behavior. This includes skills (`SKILL.md`), top-level instruction files (`AGENTS.md`, `CLAUDE.md`, repo-level agent docs), subagent and agent definitions, and any other rule/instruction entry point.

Required upstream references are listed alongside the work they govern: see [Skill Creation or Update](#skill-creation-or-update) for skill schema/structure references and [AGENTS.md Authoring](#agentsmd-authoring) for top-level instruction-file references. Load them when the task scope warrants; for small edits (description rewrites, wording tweaks, index updates, typo fixes), skip the load.

## Audit Scope

- When auditing instruction files, analyze only the file's literal contents. Exclude system- and client-injected prompt content from the analysis.
- For non-trivial instruction-entrypoint critiques or audits, invoke `critique-workflow` first and follow its procedure. Default to autonomous mode unless I explicitly ask for walkthrough gating.
- Audit for duplicate or conflicting instructions across all repository instruction entrypoints (top-level instruction files, skills, agent/subagent definitions).
- Prefer a single canonical source and cross-reference it rather than duplicating the same guidance — this applies equally to skills, `AGENTS.md`, `CLAUDE.md`, and agent definitions.
- When multiple files could host the same policy, treat the most specific skill as canonical and have broader files cross-reference it.
- When a rule already exists canonically, reference the canonical instruction instead of restating the same normative rule in another instruction file unless the local file adds a necessary scoped delta.
- When resolving duplicate or conflicting guidance, run a holistic cross-entrypoint analysis first and avoid patching each copy independently.
- Bias toward removing duplicated instruction text and improving the best canonical owner (clarification, correction, and/or discoverability). Add or keep non-canonical references only when they materially improve discoverability or scoped context.
- Flag or remove drift-prone duplication that can diverge from real behavior over time.

## Mandatory Instruction Authoring Workflow

Use this workflow when I ask you to encode, correct, or enhance instruction guidance.

1. Load `writing-style`, then `simple-english`, before drafting or revising instruction prose. If either skill is not loaded, stop and load it before continuing.
2. Scan local and global instructions, skills, and relevant mechanical enforcement (code, tests, linters, hooks, schemas, scripts) for intent coverage, including partial coverage, and for conflicts. Compare the draft against live MCP, CLI help, and upstream docs when they exist. Keep only the delta that the live surfaces do not already state.
3. Before adding always-loaded guidance, check scope and context cost, and look for chances to keep core instructions short by moving long reference material to linked assets.
4. Treat durable-directive cues (for example "every", "always", "from now on", or "should include") as instruction-update candidates by default, even when a memory update may also apply.
5. Determine scope and target first across executable enforcement and instruction-file handling: executable enforcement surfaces (code, tests, linters, hooks, schemas, scripts), repository-wide instruction, sub-directory instruction (the nearest applicable instruction entrypoint such as `<subdir>/AGENTS.md` or path-scoped `*.instructions.md`), global instruction, and instruction file vs. skill. Then decide where to save the directive on the selected instruction-file scope before closing the turn. If scope is mixed or ambiguous, ask me before applying. If coverage already exists, extend or reconcile it instead of creating duplicates.
6. For duplicate/conflict fixes, compare all overlapping entrypoints, choose the single best canonical owner, and improve that owner first (clarification, correction, and/or discoverability) instead of spreading equivalent edits across multiple files.
7. Before replacing non-canonical copies with references, assess whether those references are worth maintaining; if canonical discoverability improvements already cover routing needs, remove the duplicates without adding cross-reference maintenance.
8. Prefer executable enforcement over prose when feasible. If behavior cannot be encoded mechanically, keep instruction text as fallback context.
9. Draft the exact wording changes and ask me to confirm before applying.
10. Apply the confirmed wording in versioned instruction files on the selected scope, then complete required mechanical follow-ups (index entries, cross-references). Do not treat a harness-memory update as completion.
11. If no instruction-file change is made, provide an explicit no-change rationale with citation and get my confirmation before closing.
12. When memory is also warranted, store or update memory in the same task. Memory augments persistence and never substitutes for versioned instruction changes.

## Validation

- Validate skill metadata, structure, and behavior against the loaded specs.
- Validate and audit each skill `description` and each `AGENTS.md` skill-index one-line summary for discoverability quality, including clear invocation cues and relevant trigger keywords, and avoid "how it works" or internal-mechanics wording.
- Apply shared prose conventions from `writing-style`. For instruction discoverability and clarity, use domain jargon only when plain wording loses essential meaning, and do not treat local term frequency as justification to introduce broader or overloaded meanings.
- Before finalizing instruction-file edits, verify that both `writing-style` and `simple-english` were loaded in the same run.
- When renaming or restructuring an instruction file or skill, search the repository for stale references and update them.
- Run a duplication/conflict sweep for normative conventions across instruction entrypoints (for example: path conventions, naming rules, required artifacts, handoff contracts, and lifecycle states) and resolve conflicts before shipping.
- Before adding or changing instruction guidance, run the [Mandatory Instruction Authoring Workflow](#mandatory-instruction-authoring-workflow).
- For durable-directive requests, verify the selected persistence surface explicitly: chosen scope, instruction files updated (or an explicit no-change rationale with my confirmation), and memory updated only when applicable. Memory-only outcomes are invalid unless I explicitly reject instruction-file updates after you ask.
- For external documentation references, keep local guidance concise and project-specific and link to canonical upstream documentation instead of copying large reference material that can drift.
- For imported skills, verify `metadata.imported.from` and `metadata.imported.date` exist in frontmatter, `from` points to the canonical upstream `SKILL.md`, and `date` is the import date in `YYYY-MM-DD`.
- For imported skills, preserve a 1:1 copy of upstream content by default; if you must diverge locally, keep the delta minimal and explicit.
- For imported skills with local deltas, require `references/import-instructions.md` in the skill directory with rationale and re-apply steps for every local modification.
- If an imported skill has no non-canonical local deltas, do not create `references/import-instructions.md`.
- In `references/import-instructions.md`, document local deltas only; do not restate instructions that already exist in the canonical imported skill.
- Treat `metadata.imported.from` and `metadata.imported.date` handling as canonical imported-skill policy; do not duplicate that policy in per-skill `references/import-instructions.md` files.
- For imported skills, run an update check against `metadata.imported.from` and compare current local files to upstream content since `metadata.imported.date`; report all deltas and do not apply them without my explicit approval.
- For imported skills, validate that files contain no HTML comment markers and no invisible characters before shipping.
- When changing canonical locations, naming conventions, or handoff contracts, include migration guidance (or an explicit no-migration decision) and update dependent references in the same change.
- Verify every `assets/…` (or equivalent referenced-resource) path resolves to an existing file and that the asset's current contents still match how the body cites them.
- Verify every concrete claim in the file before shipping: every command runs, every flag behaves as stated, every URL resolves, every directive, or syntax example matches current tool behavior. Inherited assumptions from a source skill or older docs do not count as verified.
- For non-trivial skill behavior edits and description-focused edits, load `agent-instructions-evaluation` and follow its evaluation workflows before shipping.
- For lint execution policy and run order, follow the `linting` skill.
- For changes that touch the `AGENTS.md` skill index or any skill directory under `.agents/skills/`, validate skill-index sync by running `lint-skill-index`, preferring the `mise-run_task` MCP tool when available and falling back to `mise run lint-skill-index`. If the task is unavailable in the current environment, verify manually that every `.agents/skills/<dir>/` has a corresponding `AGENTS.md` index entry and every index entry maps to a real skill directory.

## Critique

The repository's general post-validation critique gate (defined in the top-level instruction file) applies to every change. This skill adds the following instruction-file-specific checks; apply them during that critique pass rather than as a separate cycle:

- Does this rule conflict with another instruction entry point?
- Did this change account for pre-existing coverage (including partial coverage) and conflicting mechanical enforcement before introducing new instruction text?
- Would a reasonable agent misread it?
- Does it over- or under-constrain compared to my actual intent?
- Is the canonical source still canonical after this edit?
- Did this change restate a canonical instruction locally where a cross-reference should be used?
- Are there unresolved duplicated or contradictory conventions across instruction entrypoints after this edit?
- Did external documentation guidance stay link-first instead of copying drift-prone reference material?
- Did the edit restate behavior that live MCP, CLI help, or upstream docs already expose instead of keeping a minimal local delta?
- After checking scope and context cost, confirm that long reference material lives in linked assets, and that narrow domain rules live in the most specific skill instead of broad instruction files.
- If canonical locations, naming conventions, or handoff contracts changed, did I include migration guidance (or an explicit no-migration decision) and update dependents?
- Does any rule contain authoring meta-commentary that belongs in the authoring skill?
- Before prose edits, did I load `writing-style` and `simple-english` as required?

## Authoring Style

- Write concise rules using imperative language optimized for accurate and efficient agentic execution.
- Follow `writing-style` for shared prose and tone conventions before applying the instruction-specific rules in this section.
- Write instructions so they work across agent tools. Describe required capabilities and repeatable steps, and avoid model-specific tricks.
- Reference skill names with backticks only. Do not use Markdown links for skill-name references.
- Prefer executable enforcement over prose when feasible: if a rule can be implemented in code, tests, linters, hooks, schemas, or scripts, implement that first and keep instruction text as fallback context for behavior that cannot be encoded.
- Avoid naming specific models, effort levels, tools, or products in reusable instructions unless the file is intentionally tool-specific.
- Instruct agents to choose execution approach based on efficiency, cost, capability, and task requirements instead of fixed named components.
- Prefer clear, specific, and deterministic instructions that can be delegated to lower-cost but capable subagents.
- Prefer delegating concrete execution work over delegating open-ended "thinking" work to subagents.
- Ground guidance in observed project reality and concrete failure modes (not generic "best practices"), per [Best practices for skill creators](https://agentskills.io/skill-creation/best-practices).
- Keep high-value "gotchas" in the always-loaded body when they prevent common, costly mistakes; move bulky reference material to assets for progressive disclosure.
- Follow `coding-guidelines` skill Markdown guidance.
- Use me-style phrasing when referring to me in instruction text: write forms like `ask me`, `when I ask`, and `my`, and avoid third-person requester phrasing.
- Use you-style phrasing when referring to the executing agent in instruction text: write forms like `you`, `your`, and `when you`, and avoid third-person agent phrasing.
- Keep behavioral guidance and authoring meta-commentary separate. Behavioral rules tell executing agents what to do; meta-commentary (labels like "this is the canonical X", directives about how other files should reference the rule, taxonomy notes, audience asides) tells skill authors how to treat the rule. Meta-commentary belongs in the authoring skill (`agent-instructions-authoring`), not embedded in the behavioral rule itself.
- When a skill has critique findings that apply only to its own domain, place them in a `## Critique` section that defers to the top-level critique gate and lists only the domain-specific checks. Do not restate the gate itself, and do not push domain-specific findings up into top-level instruction files (e.g., `AGENTS.md`).

## Skill Creation or Update

This section governs how to create, edit, and structure individual skills.

### Required references for skill structural changes

When creating a new skill, renaming a skill, or changing frontmatter or directory structure, load these references before editing:

- [Agent Skills specification](https://agentskills.io/specification) — canonical `SKILL.md` frontmatter schema, directory layout, and loading model.
- Harness-specific skills documentation for each known conformant harness:
  - **Claude Code** — [Skills](https://code.claude.com/docs/en/skills)
  - **OpenCode** — [Skills](https://opencode.ai/docs/skills/)
  - **GitHub Copilot CLI** — [Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)

Compare each harness's frontmatter schema against the Agent Skills specification. Identify which fields are shared across harnesses, which are harness-specific extensions, and where any structural deviations exist.

When a harness requires a structural deviation that cannot be expressed within the `SKILL.md` format, surface the conflict to me and present ordered alternatives — a harness-specific companion file or accepting a capability gap on that harness.

Use the loaded specs as the active source of truth; derive requirements dynamically from the references and current repository state rather than static assumptions. For description rewrites, body wording changes, or other non-structural edits, skip the load.

### Frontmatter and metadata

- Set `name` to a kebab-case slug that matches the skill's directory name.
- Match every required frontmatter field to the Agent Skills specification; prefer spec fields over harness-specific extensions.
- The fields `name`, `description`, `license`, and `allowed-tools` are recognized across all known conformant harnesses. The optional spec fields `compatibility` and `metadata` are spec-defined but not documented by all harnesses — include them when useful and accept that they may be ignored.
- When you import a skill from an external source, add `metadata.imported.from` with the canonical upstream `SKILL.md` URL and `metadata.imported.date` with the import date (`YYYY-MM-DD`).
- Harness-specific fields (e.g., Claude Code's `user-invocable`, `disable-model-invocation`) are additive — include them only when intentionally targeting that harness feature, and accept that other conformant harnesses will ignore them.

### Imported skill update workflow

When a skill has `metadata.imported.from` and `metadata.imported.date`, follow this workflow:

1. Fetch the upstream source from `metadata.imported.from` and any referenced files.
2. Compare upstream content to the local imported skill directory.
3. Keep the local copy 1:1 with upstream where possible; if intentional local deviations exist, record them in `references/import-instructions.md`.
4. In `references/import-instructions.md`, write only non-canonical, skill-specific local deltas and re-apply steps; do not restate canonical imported-skill policy (including metadata handling). If no such deltas exist, do not add the file.
5. Produce a delta report that lists added, removed, and changed files plus notable behavioral changes.
6. Present the delta report to me and ask for explicit approval before applying any upstream changes.
7. After approved updates, set `metadata.imported.date` to the date of the applied import and update `references/import-instructions.md` only when non-canonical local deviations changed.

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
- When scope wording feels gated by example lists, evaluate whether removing the list or replacing it with a broader phrase preserves discoverability while expanding valid scope; expand the examples only when broad wording would reduce routing precision.
- Keep descriptions free of links, command examples, full path enumerations, and other content that belongs in the body. The `description` is a selector, not a summary.
- Keep `description` length within the specification limit and validate trigger behavior using `agent-instructions-evaluation`.
- Apply the same discoverability-first standard to `AGENTS.md` skill-index one-line summaries: emphasize user-intent/task cues and avoid internal mechanics.

### Scripts in skills

- When adding or modifying scripts referenced by a skill, follow [Using scripts in skills](https://agentskills.io/skill-creation/using-scripts).
- Prefer one-off commands only for simple, stable invocations; move repeated or complex command logic into versioned scripts under `scripts/`.
- Require non-interactive script interfaces (flags/env/stdin), explicit `--help` usage docs, clear actionable errors, structured stdout for machine-readable results, and diagnostics on stderr.
- Require predictable exit-code behavior and safe defaults (`--dry-run`, explicit confirmation flags) for stateful or destructive operations.
- State runtime prerequisites and version expectations explicitly in skill instructions when script behavior depends on them.

### Body authoring style

- Write rules as positive, imperative directives. State what to do; describe the desired end state. Reserve "do not X" or "X is wrong" framings for cases where the antipattern is concrete, plausible, high-risk, and not already excluded by a positive rule — instruction-file authoring contains several such antipatterns (e.g., assuming the harness auto-loads referenced assets, restating canonical rules in multiple entrypoints), so negative framings appear in this skill where the exception is met.
- When tightening instruction text, first check whether simple removal of extra wording preserves intent; add explicit negative admonitions only when omission would leave a realistic, high-risk misread.
- Negative rules carry two costs: they plant the anti-pattern in agent context (which can prompt the very behavior they forbid), and they can conflict with project-specific configuration (aliases, custom directories, custom commands) that legitimately uses the named token.
- Defer to upstream documentation as the durable source of truth. When the underlying system supports configuration (custom paths, directories, environment names, command aliases), reference the docs and the project's configuration; do not enumerate defaults inline as if they were invariant.
- For external documentation, prefer concise links to canonical sources and keep local instruction text focused on project-specific behavior and constraints.
- Keep guidance language-, tool-, and version-agnostic where possible. State the rule generically and use language-specific or version-specific names only as examples, not as the rule itself.
- Prefer linking to canonical documentation over restating it; restated facts drift, links do not (and broken links are caught by validation).
- For broad tool skills, structure the body by area or workflow. Give each section a short description and a canonical-doc pointer. Keep command inventories sparse.

## AGENTS.md Authoring

This section governs how to create, edit, and structure `AGENTS.md` files.

### Required references for AGENTS.md structural changes

When creating, restructuring, or pairing `AGENTS.md` with harness-specific instruction files, load these references before editing:

- **Claude Code** — [Memory & CLAUDE.md](https://code.claude.com/docs/en/memory)
- **OpenCode** — [Rules](https://opencode.ai/docs/rules/)

For small edits (rule wording tweaks, single-entry index updates), skip the load.

### Authoring behavior

- Keep `AGENTS.md` to rules that apply to all agents and all tasks, regardless of domain, language, or workflow, plus a skill index. Anything narrower belongs in a skill.
- Keep each `AGENTS.md` focused on non-obvious guidance. Record decisions, failure learnings, and constraints that are hard to infer from nearby code.
- Do not restate behavior that an agent can read directly from local code, configuration, or tests, unless that restatement adds a needed exception or caveat.
- Prefer a flat top-level rule list in `AGENTS.md`. Add sections only when grouping avoids ambiguity or improves retrieval.
- Remove authoring metacommentary from `AGENTS.md` (for example, "keep this file short"). Keep that guidance in this skill.
- Put step-by-step implementation narratives in nearby research docs. Keep `AGENTS.md` focused on reusable rules and generalized lessons.
- Treat decision sections in `AGENTS.md` as rolling records. Do not require date labels unless time is part of the rule meaning.
- Keep the `AGENTS.md` Skills preamble behavioral. Put rationale and implementation context for skill catalogs (for example, discovery-model details) in this authoring skill, not in `AGENTS.md`.
- For changes to `AGENTS.md`, any listed skill, subagent/agent definitions, or other rule entrypoints, use this skill as the canonical source.
- Extract domain-, language-, or workflow-specific guidance into skills and reference them from the index.
- Update the index in the same change that adds, renames, or removes a skill.
- Pair every `AGENTS.md` with a `CLAUDE.md` at the same path whose entire contents are the literal string `@AGENTS.md` (and nothing else). Create, move, rename, and delete them in lockstep. This ensures Claude resolves to the same canonical entry point as other harnesses.

### Required Skills section content

- Use [`assets/agents-md-index-section.template.md`](assets/agents-md-index-section.template.md) as the canonical template for the `AGENTS.md` Skills section. Mirror its preamble verbatim, adapting only the skills-location reference to the active harness.
- Populate the index from the actual skill directory: one entry per skill, using the skill's frontmatter `name` and an accurate one-line summary optimized for AGENTS.md context (it does not need to match the skill `description` verbatim). Keep summaries discoverability-first and avoid internal mechanics.
