---
name: scripts
description: Author and maintain setup, automation, and bootstrap scripts. Use when creating or modifying shell/task scripts, install flows, or system initialization routines.
---

# Script Automation Guidelines

## Project Pattern Detection

- Inspect existing scripts before making changes and follow established project conventions.
- Detect and reuse existing patterns for:
  - script entrypoint and shell options
  - naming conventions for files, functions, and variables
  - logging and confirmation helpers
  - argument parsing and help output
  - script and test directory layout
- If project patterns conflict, prefer the pattern used by nearby peer scripts.
- If no clear pattern exists, use a minimal portable baseline.

## Environment Configuration Detection

- Check for `Brewfile` before package operations and use it when present.
- Check for mise configuration files (`mise.toml`, `.config/mise/config.toml`) before runtime or version operations and use them when present.
- If neither exists, use the package/runtime manager already adopted by the project.
- Avoid introducing a second package or runtime manager without a clear reason.

## Portable Baseline (Fallback)

When no project pattern is detectable, use this shape:

```zsh
#!/usr/bin/env zsh
set -euo pipefail

main() {
  local arg=""
  # script logic
}

main "$@"
```

## Adding or Updating Scripts

1. Reuse and extend existing scripts when possible before creating new scripts.
2. Keep destructive actions behind explicit confirmation or dry-run mode.
3. Add or update tests in the project's script test location.
4. Document purpose, required inputs, and side effects in script headers or paired docs.
5. Keep scripts idempotent when rerun.
6. Keep failure modes explicit with consistent exit codes.

## Testing

- Validate normal paths and failure paths.
- Test with dry-run/noop mode when available.
- Test both interactive and non-interactive modes when applicable.
- Verify graceful handling of missing dependencies and invalid inputs.
- Verify idempotency; reruns should not produce unintended side effects.

## Integration Requirements

- Scripts must be independently executable for testing and CI.
- Scripts must handle missing dependencies gracefully.
- Scripts must use consistent exit codes.

## Reusable Task Scripts

When a task requires a script for execution:

- Check the project's task-script location(s) for existing scripts that may apply.
- Suggest modifications to existing scripts before creating new ones.
- Make new scripts generic and reusable.
- Save new scripts in the project's reusable script location.
- Write script documentation optimized for AI agents (see `coding-guidelines` skill).
