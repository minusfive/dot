#!/usr/bin/env zsh
#MISE description="Fail when Markdown files contain HTML comments"
#MISE quiet=true
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

matches="$(grep -nH -- '<!--' "${existing_files[@]}" || true)"
if [[ -n "$matches" ]]; then
  print -u2 -- "HTML comments are not allowed in Markdown files."
  print -u2 -- "$matches"
  exit 1
fi
