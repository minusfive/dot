#!/usr/bin/env zsh
#MISE description="Verify AGENTS.md skill index is in sync with .agents/skills/"

set -euo pipefail

repo_root="${MISE_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
agents_md="${repo_root}/AGENTS.md"
skills_dir="${repo_root}/.agents/skills"

if [[ ! -f "$agents_md" ]]; then
    print -u2 -- "error: ${agents_md} not found"
    exit 2
fi
if [[ ! -d "$skills_dir" ]]; then
    print -u2 -- "error: ${skills_dir} not found"
    exit 2
fi

on_disk=$(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
in_index=$(grep -E '^- `[a-z][a-z0-9-]+` —' "$agents_md" | sed -E 's/^- `([^`]+)`.*$/\1/' | sort -u)

if diff <(print -r -- "$on_disk") <(print -r -- "$in_index") >/dev/null; then
    print -- "AGENTS.md skill index is in sync with .agents/skills/"
    exit 0
fi

print -u2 -- "AGENTS.md skill index out of sync with .agents/skills/"
print -u2 -- "--- on-disk ---"
print -u2 -r -- "$on_disk"
print -u2 -- "--- in-index ---"
print -u2 -r -- "$in_index"
exit 1
