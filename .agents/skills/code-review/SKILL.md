---
name: code-review
description: Guidance to keep the Copilot code-review agent focused on PR/commit diffs and avoid wasting tokens on generated, binary, or very large files. Use when running code-review or /review style agents.
---

# Purpose
Keep automated code-review work high-signal and low-cost by constraining scope, preferring diffs, and skipping noisy or unhelpful files.

# Principles
- Analyze the diff first; prefer changed lines over scanning full repository history.
- Pre-scan for high-signal artifacts (CI failures, failing tests, stack traces, TODO/FIXME, large dependency bumps) and report them before deep analysis.
- Respect repository ignore patterns (.gitignore, .dockerignore) and explicit repo exclusions.

# Scope & Entry
- If a PR/commit context is available, only examine the changed files and their reasonable surrounding context.
- If no diff is provided, ask for the PR/commit or analyze the last commit only.

# Exclusions (skip these by default)
- Directories: node_modules, vendor, dist, build, out, target, .git, .venv, venv, .next, .expo, .cache, coverage, public, static, third_party, .parcel-cache, .serverless, terraform/.terraform
- Files: binaries, compiled artifacts, minified JS/CSS, images, fonts, archives, and any file with NUL bytes.

# File-size and content limits
- Skip files > 200 KB.
- For files 50–200 KB, analyze only the diff plus up to 500 lines of surrounding context (start/middle/end as appropriate).
- Detect minified/bundled files by long single-line lengths (>1000 chars) or lack of newlines and skip them.

# Token and match budget
- For each file, limit context to the diff + ~500 lines (approx. 2000–4000 tokens). Prefer concise summaries rather than verbatim large excerpts.
- If the change set contains >300 modified files or >5000 changed lines, produce a high-level summary and ask the user to narrow scope.
- If a repo-wide search yields >300 matches for a pattern (e.g., TODO), stop full analysis and surface the top matches with a request to focus.

# Behavior rules
- Run fast grep-style pre-scans first and summarize findings (failing test names, CI logs, stack traces, failing file paths) before deep analysis.
- Prioritize security- or correctness-sensitive areas (authentication, authorization, crypto, dependency changes, native modules, build scripts, CI configs).
- Avoid attempting builds, installs, or network fetches unless explicitly requested and the environment is prepared.
- Do not follow or fetch remote URLs found in code unless the user asks.

# Output format
- Start with a 3–5 line summary of high-impact findings.
- Provide a prioritized list of actionable items (severity, file, short description, suggested fix one-liner).
- For code changes include minimal patch suggestions (unified diff or small code snippets) limited to the affected lines.

# Secrets and sensitive data
- Never print secrets or credentials discovered in files. Redact them and recommend secure storage (secret manager) and removal from history.
- If secrets are found, suggest steps to rotate exposed credentials and create a short remediation checklist.

# Follow-up
- If more detail is requested, ask the user to narrow scope (specific files, failing test IDs, or the PR number) before deeper work.
- Offer to run a second-pass focused review only on items the user marks as high-priority.

# Rationale
These rules reduce wasted tokens and time by steering the review agent to high-value targets and preventing expensive scans of generated or irrelevant content.
