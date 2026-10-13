#!/usr/bin/env zsh
#MISE description="Create a canonical skill evaluation specification"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--skill <skill>" help="Skill directory name"
#USAGE flag "--base-path <path>" help="Repository directory; defaults to the current project root"
#USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"
#USAGE flag "--force" help="Replace an existing evaluation specification"
#USAGE flag "--dry-run" help="Show the files that would be created"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

main() {
    local project_root base_path skills_path skill skill_dir evals_dir spec temp_file
    local usage_skill="${usage_skill:-}"
    local usage_base_path="${usage_base_path:-}"
    local usage_skills_path="${usage_skills_path:-}"

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"

    base_path="$usage_base_path"
    [[ -n "$base_path" ]] || base_path="$project_root"
    [[ "$base_path" == /* ]] || base_path="${project_root}/${base_path}"
    base_path="$(cd "$base_path" 2>/dev/null && pwd -P)" ||
        die "base path '${usage_base_path:-.}' does not exist"

    skills_path="$usage_skills_path"
    [[ -n "$skills_path" ]] || skills_path="${base_path}/.agents/skills"
    [[ "$skills_path" == /* ]] || skills_path="${base_path}/${skills_path}"
    skills_path="$(cd "$skills_path" 2>/dev/null && pwd -P)" ||
        die "skills path '${usage_skills_path:-.agents/skills}' does not exist"

    skill="$usage_skill"
    [[ "$skill" =~ '^[a-z][a-z0-9-]*$' ]] ||
        die "--skill must be a descriptive kebab-case skill name"

    skill_dir="${skills_path}/${skill}"
    [[ -d "$skill_dir" ]] || die "skill not found: ${skill}"
    [[ -f "${skill_dir}/SKILL.md" ]] || die "missing ${skill}/SKILL.md"

    evals_dir="${skill_dir}/evals"
    spec="${evals_dir}/evals.json"
    if [[ -e "$spec" && "${usage_force:-false}" != "true" ]]; then
        die "evaluation specification already exists: ${spec#$base_path/}; use --force to replace it"
    fi

    print -- "Would create ${spec#$base_path/}" >&2
    if [[ "${usage_dry_run:-false}" == "true" ]]; then
        return
    fi

    mkdir -p "$evals_dir"
    temp_file="$(mktemp "${TMPDIR:-/tmp}/skill-evals.XXXXXX")"
    trap 'rm -f -- "${temp_file:-}"' EXIT
    jq -n --arg skill "$skill" '{
        skill_name: $skill,
        evals: [
            {
                id: "example-case",
                prompt: "Replace this prompt with a realistic request.",
                expected_output: "Describe the result that indicates success.",
                assertions: [
                    "Replace this assertion with a specific, verifiable result."
                ]
            }
        ]
    }' >"$temp_file"
    mv "$temp_file" "$spec"
    print -- "Created ${spec#$base_path/}"
}

main "$@"
