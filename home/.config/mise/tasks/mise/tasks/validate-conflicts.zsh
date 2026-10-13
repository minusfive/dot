#!/usr/bin/env zsh
#MISE description="Validate local and global task names do not conflict"
#MISE alias="mise:tasks:validate-conflicts"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--base-path <path>" help="Repository directory; defaults to the current project root"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

main() {
    local project_root base_path local_tasks global_tasks conflicts

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"

    base_path="${usage_base_path:-$project_root}"
    [[ "$base_path" == /* ]] || base_path="${project_root}/${base_path}"
    base_path="$(cd "$base_path" 2>/dev/null && pwd -P)" ||
        die "base path '${usage_base_path:-.}' does not exist"

    local_tasks="$(mise -C "$base_path" tasks ls --local --json | jq -r '.[] | .name, (.aliases[]? // empty)')"
    global_tasks="$(mise -C "$base_path" tasks ls --global --json | jq -r '.[] | .name, (.aliases[]? // empty)')"
    conflicts="$(comm -12 <(print -r -- "$local_tasks" | sort -u) <(print -r -- "$global_tasks" | sort -u))"
    [[ -z "$conflicts" ]] ||
        die "local tasks conflict with global tasks: ${(j:, :)${(f)conflicts}}"

    print -- "Local and global task names do not conflict."
}

main "$@"
