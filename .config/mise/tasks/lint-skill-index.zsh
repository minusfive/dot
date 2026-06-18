#!/usr/bin/env zsh
#MISE description="Verify AGENTS.md skill index is in sync with .agents/skills/"
#MISE alias="lint-skills-index"
#MISE dir="{{cwd}}"

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$repo_root" ]]; then
    print -u2 -- "error: this task must be run inside a git repository"
    exit 2
fi

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

index_block=$(
    awk '
        /^### Index$/ { in_index = 1; next }
        in_index && /^## / { in_index = 0 }
        in_index { print }
    ' "$agents_md"
)

if [[ -z "$index_block" ]]; then
    print -u2 -- "error: could not find a ### Index section in ${agents_md}"
    exit 1
fi

index_entries=$(print -r -- "$index_block" | grep -E '^- `[a-z][a-z0-9-]+` — .+$' || true)

if [[ -z "$index_entries" ]]; then
    print -u2 -- "error: no skill entries found under ### Index in ${agents_md}"
    exit 1
fi

in_index=$(print -r -- "$index_entries" | sed -E 's/^- `([^`]+)`.*$/\1/')
in_index_unique=$(print -r -- "$in_index" | sort -u)

in_index_count=$(print -r -- "$in_index" | wc -l | tr -d ' ')
in_index_unique_count=$(print -r -- "$in_index_unique" | wc -l | tr -d ' ')

if [[ "$in_index_count" != "$in_index_unique_count" ]]; then
    duplicates=$(print -r -- "$in_index" | sort | uniq -d)
    print -u2 -- "error: duplicate skill entries found in AGENTS.md index"
    print -u2 -r -- "$duplicates"
    exit 1
fi

if ! diff <(print -r -- "$on_disk") <(print -r -- "$in_index_unique") >/dev/null; then
    print -u2 -- "AGENTS.md skill index out of sync with .agents/skills/"
    print -u2 -- "--- on-disk ---"
    print -u2 -r -- "$on_disk"
    print -u2 -- "--- in-index ---"
    print -u2 -r -- "$in_index_unique"
    exit 1
fi

while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue

    skill_file="${skills_dir}/${skill}/SKILL.md"
    if [[ ! -f "$skill_file" ]]; then
        print -u2 -- "error: missing ${skill_file}"
        exit 1
    fi

    frontmatter_name=$(
        awk '
            BEGIN { in_frontmatter = 0; frontmatter_done = 0 }
            /^---$/ {
                if (in_frontmatter == 0 && frontmatter_done == 0) {
                    in_frontmatter = 1
                    next
                }
                if (in_frontmatter == 1) {
                    frontmatter_done = 1
                    exit
                }
            }
            in_frontmatter == 1 && /^name:[[:space:]]*/ {
                sub(/^name:[[:space:]]*/, "", $0)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
                print $0
                exit
            }
        ' "$skill_file"
    )

    if [[ "$frontmatter_name" != "$skill" ]]; then
        print -u2 -- "error: ${skill_file} frontmatter name '${frontmatter_name}' does not match directory name '${skill}'"
        exit 1
    fi
done <<< "$on_disk"

print -- "AGENTS.md skill index is in sync and passed integrity checks."
