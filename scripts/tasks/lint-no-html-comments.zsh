#!/usr/bin/env zsh
#MISE description="Fail when Markdown files contain HTML comments"
#USAGE arg "[files]" help="Markdown files to scan; defaults to tracked *.md/*.markdown files" var=#true

set -euo pipefail

repo_root="${MISE_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$repo_root"

if [[ -n "${usage_files:-}" ]]; then
    eval "files=($usage_files)"
else
    files=("${(@f)$(git ls-files '*.md' '*.markdown')}")
fi

if [[ ${#files[@]} -eq 0 ]]; then
    exit 0
fi

existing_files=()
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        existing_files+=("$file")
    fi
done

if [[ ${#existing_files[@]} -eq 0 ]]; then
    exit 0
fi

matches="$(
    for file in "${existing_files[@]}"; do
        awk '
            {
                marker = ""
                if (match($0, /^[[:space:]]{0,3}(```+|~~~+)/)) {
                    marker = substr($0, RSTART, RLENGTH)
                }

                if (marker != "") {
                    sub(/^[[:space:]]+/, "", marker)
                    rest = substr($0, RSTART + RLENGTH)

                    if (!in_fence) {
                        in_fence = 1
                        fence_char = substr(marker, 1, 1)
                        fence_length = length(marker)
                        next
                    }

                    if (substr(marker, 1, 1) == fence_char && length(marker) >= fence_length && rest ~ /^[[:space:]]*$/) {
                        in_fence = 0
                        next
                    }
                }

                if (!in_fence && index($0, "<!--") > 0) {
                    print FILENAME ":" FNR ":" $0
                }
            }
        ' "$file"
    done
)"
if [[ -n "$matches" ]]; then
    print -u2 -- "HTML comments are not allowed in Markdown files."
    print -u2 -- "$matches"
    exit 1
fi
