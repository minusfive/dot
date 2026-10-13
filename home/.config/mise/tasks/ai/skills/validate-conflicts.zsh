#!/usr/bin/env zsh
#MISE description="Validate local and global skill names do not conflict"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--base-path <path>" help="Repository directory; defaults to the current project root"
#USAGE flag "--global-skills-path <path>" help="Global skill directory; defaults to ~/.agents/skills"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

main() {
    local project_root base_path local_skills_path global_skills_path local_skill

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"

    base_path="${usage_base_path:-$project_root}"
    [[ "$base_path" == /* ]] || base_path="${project_root}/${base_path}"
    base_path="$(cd "$base_path" 2>/dev/null && pwd -P)" ||
        die "base path '${usage_base_path:-.}' does not exist"

    local_skills_path="${base_path}/.agents/skills"
    global_skills_path="${usage_global_skills_path:-$HOME/.agents/skills}"
    [[ "$global_skills_path" == /* ]] || global_skills_path="${base_path}/${global_skills_path}"
    global_skills_path="$(cd "$global_skills_path" 2>/dev/null && pwd -P)" ||
        die "global skills path '${usage_global_skills_path:-$HOME/.agents/skills}' does not exist"

    if [[ -d "$local_skills_path" && -d "$global_skills_path" ]]; then
        while IFS= read -r local_skill; do
            [[ -z "$local_skill" ]] && continue
            if [[ -d "${global_skills_path}/${local_skill}" ]]; then
                die "local skill conflicts with global skill: ${local_skill}"
            fi
        done < <(
            find "$local_skills_path" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) \
                -exec basename {} \; | sort
        )
    fi

    print -- "Local and global skill names do not conflict."
}

main "$@"
