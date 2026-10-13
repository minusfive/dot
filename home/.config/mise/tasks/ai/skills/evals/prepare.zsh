#!/usr/bin/env zsh
#MISE description="Create a canonical skill evaluation workspace"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--skill <skill>" help="Skill directory name"
#USAGE flag "--iteration <number>" help="Evaluation iteration number" default="1"
#USAGE flag "--base-path <path>" help="Repository directory; defaults to the current project root"
#USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"
#USAGE flag "--dry-run" help="Show the files that would be created"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

main() {
    local project_root base_path skills_path skill skill_dir spec workspace_root iteration_dir
    local case_id case_dir configuration
    local usage_skill="${usage_skill:-}"
    local usage_base_path="${usage_base_path:-}"
    local usage_iteration="${usage_iteration:-1}"
    local usage_skills_path="${usage_skills_path:-}"
    local -a case_ids

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
    [[ "$usage_iteration" =~ '^[1-9][0-9]*$' ]] ||
        die "--iteration must be a positive integer"

    skill_dir="${skills_path}/${skill}"
    spec="${skill_dir}/evals/evals.json"
    [[ -f "$spec" ]] || die "evaluation specification not found for skill: ${skill}"

    jq -e --arg skill "$skill" '
        (keys | sort) == ["evals", "skill_name"] and
        .skill_name == $skill and
        (.evals | type == "array" and length > 0) and
        all(.evals[];
            (.id | type == "string" and test("^[a-z][a-z0-9-]*$")) and
            (.prompt | type == "string" and length > 0) and
            (.expected_output | type == "string" and length > 0) and
            (.assertions? == null or
                (.assertions | type == "array" and all(.[]; type == "string" and length > 0))) and
            (.files? == null or
                (.files | type == "array" and all(.[]; type == "string")))
        ) and
        ([.evals[].id] | length == (unique | length))
    ' "$spec" >/dev/null || die "invalid evaluation specification: ${spec#$base_path/}"

    case_ids=( ${(f)"$(jq -r '.evals[].id' "$spec")"} )
    workspace_root="${base_path}/.agents/eval-workspaces/${skill}"
    iteration_dir="${workspace_root}/iteration-${usage_iteration}"
    [[ ! -d "$iteration_dir" ]] ||
        die "evaluation iteration already exists: ${iteration_dir#$base_path/}; use a new iteration number"

    print -- "Would create ${iteration_dir#$base_path/}" >&2
    if [[ "${usage_dry_run:-false}" == "true" ]]; then
        return
    fi

    mkdir -p "$iteration_dir"
    jq -n --arg skill "$skill" --arg iteration "$usage_iteration" \
        --arg workspace ".agents/eval-workspaces/${skill}" \
        --argjson case_ids "$(jq -c '.evals | map(.id)' "$spec")" '{
            version: 1,
            skill_name: $skill,
            iteration: ($iteration | tonumber),
            case_ids: $case_ids,
            workspace: $workspace
        }' >"${iteration_dir}/manifest.json"

    jq -n --arg skill "$skill" --arg iteration "$usage_iteration" '{
        skill_name: $skill,
        iteration: ($iteration | tonumber),
        run_summary: {},
        delta: {}
    }' >"${iteration_dir}/benchmark.json"
    jq -n --arg skill "$skill" --arg iteration "$usage_iteration" '{
        skill_name: $skill,
        iteration: ($iteration | tonumber),
        human_review: [],
        limitations: [],
        recommendation: "hold"
    }' >"${iteration_dir}/feedback.json"
    jq -n --arg skill "$skill" --arg iteration "$usage_iteration" '{
        skill_name: $skill,
        iteration: ($iteration | tonumber),
        cases: {}
    }' >"${iteration_dir}/grading-summary.json"

    for case_id in "${case_ids[@]}"; do
        case_dir="${iteration_dir}/${case_id}"
        for configuration in with_skill old_skill; do
            mkdir -p "${case_dir}/${configuration}/outputs"
            jq -n '{total_tokens: null, duration_ms: null}' \
                >"${case_dir}/${configuration}/timing.json"
            jq -n '{
                assertion_results: [],
                summary: {
                    passed: 0,
                    failed: 0,
                    total: 0,
                    pass_rate: 0
                }
            }' >"${case_dir}/${configuration}/grading.json"
        done
    done

    print -- "Created ${iteration_dir#$base_path/}"
}

main "$@"
