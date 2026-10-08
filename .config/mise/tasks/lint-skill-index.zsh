#!/usr/bin/env zsh
#MISE description="Verify home AGENTS.md skill index is in sync with home/.agents/skills/"
#MISE alias="lint-skills-index"
#MISE dir="{{cwd}}"

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$repo_root" ]]; then
    print -u2 -- "error: this task must be run inside a git repository"
    exit 2
fi

agents_md="${repo_root}/home/AGENTS.md"
skills_dir="${repo_root}/home/.agents/skills"

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
    print -u2 -- "home/AGENTS.md skill index out of sync with home/.agents/skills/"
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

    imported_metadata=$(
        awk '
            BEGIN {
                in_frontmatter = 0
                frontmatter_done = 0
                in_metadata = 0
                in_imported = 0
                has_imported = 0
                imported_from = ""
                imported_date = ""
            }
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
            in_frontmatter == 1 && /^metadata:[[:space:]]*$/ {
                in_metadata = 1
                next
            }
            in_frontmatter == 1 && in_metadata == 1 {
                if ($0 ~ /^[^[:space:]]/) {
                    in_metadata = 0
                    in_imported = 0
                    next
                }
                if ($0 ~ /^  imported:[[:space:]]*$/) {
                    has_imported = 1
                    in_imported = 1
                    next
                }
                if ($0 ~ /^  [^[:space:]][^:]*:[[:space:]]*/ && $0 !~ /^  imported:[[:space:]]*$/) {
                    in_imported = 0
                    next
                }
                if (in_imported == 1 && $0 ~ /^    from:[[:space:]]*/) {
                    imported_from = $0
                    sub(/^    from:[[:space:]]*/, "", imported_from)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", imported_from)
                    next
                }
                if (in_imported == 1 && $0 ~ /^    date:[[:space:]]*/) {
                    imported_date = $0
                    sub(/^    date:[[:space:]]*/, "", imported_date)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", imported_date)
                }
            }
            END {
                print has_imported "\t" imported_from "\t" imported_date
            }
        ' "$skill_file"
    )

    IFS=$'\t' read -r has_imported metadata_imported_from metadata_imported_date <<< "$imported_metadata"

    if [[ "$has_imported" == "1" || -n "$metadata_imported_from" || -n "$metadata_imported_date" ]]; then
        if [[ "$has_imported" != "1" ]]; then
            print -u2 -- "error: ${skill_file} has imported metadata fields but no metadata.imported block"
            exit 1
        fi
        if [[ -z "$metadata_imported_from" ]]; then
            print -u2 -- "error: ${skill_file} has metadata.imported but metadata.imported.from is missing"
            exit 1
        fi
        if [[ ! "$metadata_imported_from" =~ '^https?://[^[:space:]]+$' ]]; then
            print -u2 -- "error: ${skill_file} metadata.imported.from must be an absolute URL (got '${metadata_imported_from}')"
            exit 1
        fi
        if [[ -z "$metadata_imported_date" ]]; then
            print -u2 -- "error: ${skill_file} has metadata.imported but metadata.imported.date is missing"
            exit 1
        fi
        if [[ ! "$metadata_imported_date" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
            print -u2 -- "error: ${skill_file} metadata.imported.date must use YYYY-MM-DD (got '${metadata_imported_date}')"
            exit 1
        fi

        import_instructions_file="${skills_dir}/${skill}/references/import-instructions.md"
        if [[ -f "$import_instructions_file" ]]; then
            if ! rg -q '^## Local modifications$' "$import_instructions_file"; then
                print -u2 -- "error: ${import_instructions_file} must include a '## Local modifications' section"
                exit 1
            fi
            if ! rg -q '^## Re-apply steps' "$import_instructions_file"; then
                print -u2 -- "error: ${import_instructions_file} must include a '## Re-apply steps' section"
                exit 1
            fi
            if ! rg -q 'local modifications only' "$import_instructions_file"; then
                print -u2 -- "error: ${import_instructions_file} must state that it documents local modifications only"
                exit 1
            fi
            if rg -q 'metadata\.imported\.' "$import_instructions_file"; then
                print -u2 -- "error: ${import_instructions_file} must not restate canonical metadata.imported policy"
                exit 1
            fi
            if rg -q '^None\.' "$import_instructions_file"; then
                print -u2 -- "error: remove ${import_instructions_file} when there are no meaningful local deltas"
                exit 1
            fi
        fi

        if rg --pcre2 -n '<!--|-->' "${skills_dir}/${skill}" >/dev/null 2>&1; then
            print -u2 -- "error: imported skill '${skill}' contains comments; remove comment content from imported files"
            rg --pcre2 -n '<!--|-->' "${skills_dir}/${skill}" | head -n 5 >&2
            exit 1
        fi

        if rg --pcre2 -n '\p{Cf}' "${skills_dir}/${skill}" >/dev/null 2>&1; then
            print -u2 -- "error: imported skill '${skill}' contains invisible Unicode characters"
            rg --pcre2 -n '\p{Cf}' "${skills_dir}/${skill}" | head -n 5 >&2
            exit 1
        fi
    fi
done <<< "$on_disk"

print -- "home/AGENTS.md skill index is in sync and passed integrity checks."
