---
name: rewrite-imports
description: Migrate import paths safely across many files. Use when renaming modules/packages, moving files, or bulk-rewriting import statements after refactors.
---

# Rewrite Imports

Bulk-migrate import statements from one module to another across a codebase.

## Workflow

### 1. Discover affected files

Use content-search capability with a "files with matches" output mode to find all files importing from the old module path.

### 2. Edit imports

Use parallel editing workflows (for example, one batch per similar file group). Before editing any file, **read it first** so exact replacement matching succeeds.

**Multi-line imports:** These are the most common source of failed edits. The `old_string` must match exact whitespace, newlines, and indentation of the multi-line import block. Always copy the import exactly as it appears in the file.

**Don't manually merge imports.** If a file already imports from the target module, just add a new import line. Prettier's `organize-imports` plugin will merge duplicates automatically.

### 3. Format and verify

Run the repository's formatting and type-check validation workflow to catch import-order and type issues.
