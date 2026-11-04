---
name: security
description: Route security-sensitive work and record secret, permission, network, dependency, and sensitive-configuration evidence. Use during implementation, review, audit, or closure when security risk is present.
---

# Security

Use this skill when a task touches secrets, credentials, permissions, system changes, external network access, dependency risk, or sensitive configuration. If none of these conditions apply, record that security routing is not applicable and continue with the owning skill.

## Owner controls

Prevent secrets from entering source files, commits, artifacts, checkpoints, logs, and evaluation output. Use an approved secret manager or agent for credentials. Scan changed files and generated evidence for secret-like values before handoff.

Check logs, command output, review comments, and saved artifacts for sensitive values. Redact credentials, tokens, cookies, private keys, signed URL query values, and secret configuration values before you preserve them.

Apply least privilege to workers, files, tools, credentials, network access, and system changes. Grant only the access required for the named task and remove temporary access after the handoff.

Check file, directory, process, and service permissions before execution. Reject writable or executable paths that exceed the task boundary. Record the permission check and its result.

Use secure network defaults. Require encrypted transport, verify the expected host, limit destinations, disable unnecessary network access, and reject unauthenticated or unverified connections.

Pin dependencies and action versions for security-sensitive tools. Record the source, version, integrity evidence, and update decision for every dependency that the change adds or updates.

## Conditional routing

Route the affected lane to security review when evidence shows a security-sensitive boundary. Name the boundary, affected paths, runtime target, and state owner. Keep the lane frozen when a required security decision is unavailable. Do not add a second lifecycle. Use the owning workflow skill for story, review, or delivery state. Require current-turn authorization for security-sensitive mutations. Freeze the lane when authorization expires.

## Secret and redaction evidence

Keep safe repository-relative or `~`-relative paths, refs, URLs, issue or pull request references, worktree paths, and artifact identifiers literal when they contain no sensitive value. Redact credentials, tokens, cookies, private keys, signed URL query values, and secret configuration values before handoffs, logs, checkpoints, findings, or evaluation output. Preserve a safe identifier, such as the host and path with a redacted query marker. Record that redaction occurred. Record `clean` when no sensitive value appears. Record `redacted` when a sensitive value was removed. Do not treat a redaction marker as evidence that the underlying value is safe.

## Findings and dispositions

Record each security finding with its source, affected boundary, validation evidence, owner, disposition, and residual risk. Use the disposition states `unresolved`, `resolved`, `rejected`, and `accepted-risk`. Keep `unresolved` findings open. Require evidence for every terminal disposition. Use `critique-workflow` for verdict tokens and decision-log format. Use `review-delivery` for candidate findings and pull request review.

## Closure evidence

Close security work only when the record includes:

- the reviewed scope and exact references;
- the secret-prevention, sensitive-log, permission, least-privilege, network, and dependency checks and validation results;
- secret and redaction status;
- terminal disposition for every finding;
- residual risk and its owner;
- the next workflow handoff.

Keep merge authority with me. Do not authorize a commit, push, pull request update, or merge from this skill.
