#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  manage-agentic-project.sh --project <project-name> (--prompt <text> | --prompt-file <path>) [--force] [--repo-root <path>]

Options:
  --project       Project name (letters, numbers, dot, underscore, hyphen)
  --prompt        Initial prompt text
  --prompt-file   File containing initial prompt text
  --force         Overwrite existing PROMPT.md
  --repo-root     Repository root (defaults to current git repo root)
  --help          Show help
EOF
}

err() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

project_name=""
prompt_text=""
prompt_file=""
force=false
repo_root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || err "--project requires a value"
      project_name="$2"
      shift 2
      ;;
    --prompt)
      [[ $# -ge 2 ]] || err "--prompt requires a value"
      prompt_text="$2"
      shift 2
      ;;
    --prompt-file)
      [[ $# -ge 2 ]] || err "--prompt-file requires a value"
      prompt_file="$2"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    --repo-root)
      [[ $# -ge 2 ]] || err "--repo-root requires a value"
      repo_root="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$project_name" ]] || err "Missing required argument: --project"
[[ "$project_name" != "." && "$project_name" != ".." ]] || err "Invalid project name: $project_name"
[[ "$project_name" != */* ]] || err "Project name must not contain '/'"
[[ "$project_name" =~ ^[A-Za-z0-9._-]+$ ]] || err "Invalid project name '$project_name' (allowed: letters, numbers, dot, underscore, hyphen)"

if [[ -n "$prompt_text" && -n "$prompt_file" ]]; then
  err "Use either --prompt or --prompt-file, not both"
fi

if [[ -z "$prompt_text" && -z "$prompt_file" ]]; then
  err "Missing prompt input: provide --prompt or --prompt-file"
fi

if [[ -n "$prompt_file" ]]; then
  [[ -f "$prompt_file" ]] || err "Prompt file does not exist: $prompt_file"
  [[ -r "$prompt_file" ]] || err "Prompt file is not readable: $prompt_file"
  prompt_text="$(cat "$prompt_file")"
fi

[[ -n "${prompt_text//[$'\t\r\n ']}" ]] || err "Initial prompt is empty"

if [[ -z "$repo_root" ]]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[[ -n "$repo_root" ]] || err "Not inside a git repository (or provide --repo-root)"
[[ -d "$repo_root" ]] || err "Repository root does not exist: $repo_root"

project_dir="$repo_root/.agents/projects/$project_name"
plans_dir="$project_dir/plans"
research_dir="$project_dir/research"
tmp_dir="$project_dir/tmp"
prompt_md="$project_dir/PROMPT.md"
project_gitignore="$project_dir/.gitignore"

mkdir -p "$plans_dir" "$research_dir" "$tmp_dir"

if [[ -f "$prompt_md" && "$force" != true ]]; then
  err "PROMPT.md already exists at $prompt_md (use --force to overwrite)"
fi

cat >"$prompt_md" <<EOF
# Project: $project_name

## Initial Prompt

$prompt_text

## Workspace Usage

- Store plans as separate files in \`plans/\` (for persisted planning and persisted subagents orchestration synchronization artifacts).
- Store research as separate files in \`research/\`.
- Use \`tmp/\` for temporary files, large outputs, intermediate artifacts, and non-persisted subagents orchestration synchronization artifacts.
- Delete temporary files in \`tmp/\` when the project is complete.
EOF

cat >"$project_gitignore" <<'EOF'
# Ignore temporary project artifacts
tmp/*
EOF

printf 'Initialized project workspace: %s\n' "$project_dir"
printf 'Created/updated: %s\n' "$prompt_md"
printf 'Ensured: %s %s %s %s\n' "$plans_dir" "$research_dir" "$tmp_dir" "$project_gitignore"
