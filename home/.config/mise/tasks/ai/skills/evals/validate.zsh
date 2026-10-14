#!/usr/bin/env zsh
#MISE description="Validate skill evaluation specs and repository-local workspaces"
#USAGE flag "--base-path <path>" help="Directory to validate; defaults to the current project root"
#USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"
#MISE dir="{{cwd}}"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

valid_json() {
    local file="$1"
    jq empty "$file" >/dev/null 2>&1 ||
        die "invalid JSON: ${file#$base_path/}"
}

main() {
    local project_root base_path skills_path workspace_dir skill_root skill_dir skill evals_dir spec
    local workspace_skill iteration_dir iteration_name manifest case_ids expected_ids
    local workspace_entry discoverability_dir case_entry case_name configuration_dir
    local extra legacy_artifact candidate_root existing_root root_is_known
    local candidate matched_workspace_skill
    typeset -a skills_dirs workspace_skill_roots

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"

    base_path="${usage_base_path:-$project_root}"
    if [[ "$base_path" != /* ]]; then
        base_path="${project_root}/${base_path}"
    fi
    base_path="$(cd "$base_path" 2>/dev/null && pwd -P)" ||
        die "base path '${usage_base_path:-.}' does not exist"

    skills_path="${usage_skills_path:-${base_path}/.agents/skills}"
    [[ "$skills_path" == /* ]] || skills_path="${base_path}/${skills_path}"
    skills_path="$(cd "$skills_path" 2>/dev/null && pwd -P)" ||
        die "skills path '${usage_skills_path:-.agents/skills}' does not exist"
    skills_dirs=("$skills_path")
    # Repositories can contain multiple .agents/skills trees that share one workspace directory.
    workspace_skill_roots=("$skills_path")
    while IFS= read -r candidate_root; do
        root_is_known=false
        for existing_root in "${workspace_skill_roots[@]}"; do
            if [[ "$existing_root" == "$candidate_root" ]]; then
                root_is_known=true
                break
            fi
        done
        [[ "$root_is_known" == true ]] || workspace_skill_roots+=("$candidate_root")
    done < <(find "$base_path" -type d -path '*/.agents/skills' -print)
    workspace_dir="${base_path}/.agents/eval-workspaces"

    for skill_root in "${skills_dirs[@]}"; do
        for skill_dir in "$skill_root"/*; do
            [[ -d "$skill_dir" ]] || continue
            skill="${skill_dir:t}"
            evals_dir="${skill_dir}/evals"
            [[ -d "$evals_dir" ]] || continue

            spec="${evals_dir}/evals.json"
            [[ -f "$spec" && ! -L "$spec" ]] ||
                die "${skill}/evals/evals.json must be a regular local file"

            extra="$(find "$evals_dir" -mindepth 1 -maxdepth 1 ! -name evals.json -print -quit)"
            [[ -z "$extra" ]] ||
                die "${skill}/evals may contain only evals.json"

            valid_json "$spec"
            jq -e --arg skill "$skill" '
            (keys | sort) == ["evals", "skill_name"] and
            .skill_name == $skill and
            (.evals | type == "array" and length > 0) and
            all(.evals[];
                (type == "object") and
                ((keys - ["assertions", "expected_output", "files", "id", "prompt"]) | length == 0) and
                (.id | type == "string" and length > 0 and test("^[a-z][a-z0-9-]*$")) and
                (.prompt | type == "string" and length > 0) and
                (.expected_output | type == "string" and length > 0) and
                (.assertions? == null or
                    (.assertions | type == "array" and length > 0 and
                        all(.[]; type == "string" and length > 0))) and
                (.files? == null or
                    (.files | type == "array" and all(.[]; type == "string")))
            ) and
            ([.evals[].id] | length == (unique | length))
            ' "$spec" >/dev/null ||
                die "invalid evaluation spec: ${spec#$base_path/}"
        done
    done

    [[ -d "$workspace_dir" ]] || {
        print -- "Skill evaluation specs are valid. No repository-local workspaces found."
        return
    }

    if find "$workspace_dir" -type l -print -quit | grep -q .; then
        die "evaluation workspaces must not contain symlinks"
    fi
    legacy_artifact="$(find "$workspace_dir" -type f -path '*/outputs/timing-*.json' -print -quit)"
    [[ -z "$legacy_artifact" ]] ||
        die "legacy timing artifact must be replaced by timing.json: ${legacy_artifact#$base_path/}"
    legacy_artifact="$(find "$workspace_dir" -type d \( -name with_change -o -name old_version \) -print -quit)"
    [[ -z "$legacy_artifact" ]] ||
        die "legacy evaluation configuration directory: ${legacy_artifact#$base_path/}"

    for workspace_skill in "$workspace_dir"/*; do
        [[ -d "$workspace_skill" ]] || continue
        skill="${workspace_skill:t}"
        spec=""
        matched_workspace_skill=false
        for skill_root in "${workspace_skill_roots[@]}"; do
            candidate="${skill_root}/${skill}/evals/evals.json"
            if [[ -f "$candidate" ]]; then
                matched_workspace_skill=true
                [[ "$skill_root" == "$skills_path" ]] && spec="$candidate"
            fi
        done
        [[ "$matched_workspace_skill" == true ]] ||
            die "workspace has no matching skill spec: ${skill}"
        [[ -n "$spec" ]] || continue
        expected_ids="$(jq -c '[.evals[].id]' "$spec")"

        for workspace_entry in "$workspace_skill"/*; do
            [[ -d "$workspace_entry" ]] || continue
            case "${workspace_entry:t}" in
                iteration-*) ;;
                discoverability)
                    discoverability_dir="$workspace_entry"
                    for extra in queries.json results.json; do
                        [[ -f "${discoverability_dir}/${extra}" ]] ||
                            die "missing ${discoverability_dir#$base_path/}/${extra}"
                        valid_json "${discoverability_dir}/${extra}"
                    done
                    ;;
                *) die "invalid evaluation workspace entry: ${workspace_entry#$base_path/}" ;;
            esac
        done

        for iteration_dir in "$workspace_skill"/iteration-*; do
            [[ -d "$iteration_dir" ]] || continue
            iteration_name="${iteration_dir:t}"
            [[ "$iteration_name" =~ '^iteration-[0-9]+$' ]] ||
                die "invalid workspace directory: ${workspace_skill#$base_path/}/${iteration_name}"

            manifest="${iteration_dir}/manifest.json"
            [[ -f "$manifest" ]] || die "missing ${manifest#$base_path/}"
            valid_json "$manifest"
            jq -e --arg skill "$skill" --arg iteration "${iteration_name#iteration-}" \
                --argjson expected "$expected_ids" '
                .version == 1 and
                .skill_name == $skill and
                (.iteration | tostring) == $iteration and
                (.case_ids | type == "array" and . == $expected)
            ' "$manifest" >/dev/null ||
                die "invalid evaluation manifest: ${manifest#$base_path/}"

            for extra in benchmark.json feedback.json grading-summary.json; do
                [[ -f "${iteration_dir}/${extra}" ]] ||
                    die "missing ${iteration_dir#$base_path/}/${extra}"
                valid_json "${iteration_dir}/${extra}"
                jq -e --arg skill "$skill" --arg iteration "${iteration_name#iteration-}" '
                    .skill_name == $skill and (.iteration | tostring) == $iteration
                ' "${iteration_dir}/${extra}" >/dev/null ||
                    die "invalid report identity: ${iteration_dir#$base_path/}/${extra}"
            done

            for case_entry in "$iteration_dir"/*; do
                [[ -d "$case_entry" ]] || continue
                case_name="${case_entry:t}"
                jq -e --arg case_id "$case_name" \
                    'any(.evals[]; .id == $case_id)' "$spec" >/dev/null ||
                    die "workspace case is not in the evaluation spec: ${case_entry#$base_path/}"

                for configuration_dir in "$case_entry"/*; do
                    [[ -d "$configuration_dir" ]] || continue
                    case "${configuration_dir:t}" in
                        with_skill|old_skill) ;;
                        *) die "invalid evaluation configuration: ${configuration_dir#$base_path/}" ;;
                    esac
                    [[ -d "${configuration_dir}/outputs" ]] ||
                        die "missing output directory: ${configuration_dir#$base_path/}/outputs"
                    for extra in timing.json grading.json; do
                        [[ -f "${configuration_dir}/${extra}" ]] ||
                            die "missing ${configuration_dir#$base_path/}/${extra}"
                        valid_json "${configuration_dir}/${extra}"
                    done
                done
            done
        done
    done

    print -- "Skill evaluation specs and repository-local workspaces are valid."
}

main "$@"
