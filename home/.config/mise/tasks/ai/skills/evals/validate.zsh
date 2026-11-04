#!/usr/bin/env zsh
#MISE description="Validate skill evaluation specs and repository-local workspaces"
#MISE quiet=true
#USAGE flag "--base-path <path>" help="Directory to validate; defaults to the current project root"
#USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"
#MISE dir="{{cwd}}"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

typeset -ga migration_sources migration_targets legacy_preparation_skills
typeset -r task_source_dir="${0:A:h}"

is_migration_source() {
    local name="$1"
    local source
    for source in "${migration_sources[@]}"; do
        [[ "$source" == "$name" ]] && return 0
    done
    return 1
}

is_legacy_preparation_skill() {
    local name="$1"
    local skill
    for skill in "${legacy_preparation_skills[@]}"; do
        [[ "$skill" == "$name" ]] && return 0
    done
    return 1
}

resolve_workspace_skill() {
    local resolved="$1"
    local source target index
    while :; do
        index=1
        while (( index <= ${#migration_sources[@]} )); do
            source="${migration_sources[$index]}"
            if [[ "$source" == "$resolved" ]]; then
                target="${migration_targets[$index]}"
                resolved="$target"
                break
            fi
            index=$((index + 1))
        done
        (( index <= ${#migration_sources[@]} )) || break
    done
    print -r -- "$resolved"
}

reject_duplicate_skill_names() {
    local root_base_path="$1"
    local first_root second_root skill_dir duplicate_dir skill
    local -i first_index second_index
    local -a roots

    shift
    roots=("$@")

    for (( first_index = 1; first_index <= ${#roots[@]}; first_index++ )); do
        first_root="${roots[$first_index]}"
        for (( second_index = first_index + 1; second_index <= ${#roots[@]}; second_index++ )); do
            second_root="${roots[$second_index]}"
            for skill_dir in "$first_root"/*; do
                [[ -d "$skill_dir" ]] || continue
                skill="${skill_dir:t}"
                duplicate_dir="${second_root}/${skill}"
                [[ -d "$duplicate_dir" ]] || continue
                die "duplicate skill name across skill roots: ${skill}; found in ${skill_dir#$root_base_path/} and ${duplicate_dir#$root_base_path/}; remove one skill or rename one before validating evaluation specs"
            done
        done
    done
}

valid_json() {
    local file="$1"
    jq empty "$file" >/dev/null 2>&1 ||
        die "invalid JSON: ${file#$base_path/}"
}

validate_evaluation_spec() {
    local skill_dir="$1"
    local skill="$2"
    local spec="$3"
    local evals_dir extra

    evals_dir="${skill_dir}/evals"
    [[ -d "$evals_dir" && ! -L "$evals_dir" ]] ||
        die "${skill}/evals must be a physical directory"
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
}

validate_evidence_file() {
    local workspace_root="$1"
    local referenced_file="$2"
    local expected_root canonical_path

    [[ "$referenced_file" != /* && "$referenced_file" != *\\* ]] ||
        die "evidence path must be relative: ${workspace_root#$base_path/}/${referenced_file}"
    case "$referenced_file" in
        .|./*|*/./*|*/.|..|../*|*/../*|*/..)
            die "evidence path is not canonical: ${workspace_root#$base_path/}/${referenced_file}"
            ;;
    esac
    expected_root="$(realpath -P "$workspace_root")" ||
        die "could not resolve evidence workspace: ${workspace_root#$base_path/}"
    canonical_path="$(realpath -P "${workspace_root}/${referenced_file}")" ||
        die "could not resolve evidence path: ${workspace_root#$base_path/}/${referenced_file}"
    [[ "$canonical_path" == "$expected_root"/* ]] ||
        die "evidence path escapes its workspace: ${workspace_root#$base_path/}/${referenced_file}"
    [[ -f "$canonical_path" && ! -L "$canonical_path" ]] ||
        die "materialized report references a missing or symlinked evidence file: ${workspace_root#$base_path/}/${referenced_file}"
}

validate_materialized_config() {
    local configuration_dir="$1"
    local skill="$2"
    local iteration="$3"
    local case_id="$4"
    local configuration="$5"

    jq -e --arg skill "$skill" --arg iteration "$iteration" --arg case "$case_id" \
        --arg configuration "$configuration" '
        (keys | sort) == ["case_id", "configuration", "duration_ms", "ended_at",
            "evidence_files", "harness_identity", "output_files", "redaction_status",
            "result", "run_id", "skill_identity", "spec_id", "started_at", "status",
            "total_tokens"] and
        .case_id == $case and .configuration == $configuration and
        (.run_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")) and
        .spec_id == ($skill + "/evals/evals.json") and
        .skill_identity == $skill and
        (.harness_identity | type == "string" and length > 0 and length <= 192) and
        (.status | IN("completed", "failed", "cancelled", "blocked")) and
        (.result | IN("passed", "failed", "cancelled", "blocked")) and
        (.started_at | type == "string" and length >= 20 and length <= 64) and
        (.ended_at | type == "string" and length >= 20 and length <= 64) and
        (.duration_ms | type == "number" and floor == . and . >= 0) and
        (.total_tokens | type == "number" and floor == . and . >= 0) and
        (.redaction_status | IN("clean", "redacted")) and
        (.output_files | type == "array" and length > 0 and
            all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$"))) and
        (.evidence_files | type == "array" and
            all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$")))
    ' "${configuration_dir}/timing.json" >/dev/null ||
        die "invalid materialized timing report: ${configuration_dir#$PWD/}/timing.json"

    jq -e --arg case "$case_id" --arg configuration "$configuration" '
        (keys | sort) == ["assertion_results", "case_id", "configuration", "redaction_status",
            "result", "run_id", "status"] and
        .case_id == $case and .configuration == $configuration and
        (.run_id | type == "string" and length > 0 and length <= 128) and
        (.status | IN("completed", "failed", "cancelled", "blocked")) and
        (.result | IN("passed", "failed", "cancelled", "blocked")) and
        (.redaction_status | IN("clean", "redacted")) and
        (.assertion_results | type == "array" and
            all(.[]; type == "object" and
                (keys | sort) == ["evidence", "id", "status"] and
                (.id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")) and
                (.status | IN("passed", "failed", "blocked")) and
                (.evidence | type == "array" and length > 0 and
                    all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$")))))
    ' "${configuration_dir}/grading.json" >/dev/null ||
        die "invalid materialized grading report: ${configuration_dir#$PWD/}/grading.json"
    [[ "$(jq -r '.run_id' "${configuration_dir}/timing.json")" ==
        "$(jq -r '.run_id' "${configuration_dir}/grading.json")" ]] ||
        die "materialized timing and grading run IDs do not match: ${configuration_dir#$PWD/}"

    while IFS= read -r referenced_file; do
        validate_evidence_file "$configuration_dir" "$referenced_file"
    done < <(jq -r '.output_files[], .evidence_files[]' "${configuration_dir}/timing.json")
    while IFS= read -r referenced_file; do
        validate_evidence_file "$configuration_dir" "$referenced_file"
    done < <(jq -r '.assertion_results[].evidence[]' "${configuration_dir}/grading.json")
}

validate_materialized_reports() {
    local iteration_dir="$1"
    local skill="$2"
    local iteration="$3"
    local report report_path referenced_file

    for report in benchmark.json feedback.json grading-summary.json; do
        report_path="${iteration_dir}/${report}"
        jq -e --arg skill "$skill" --arg iteration "$iteration" '
            .skill_name == $skill and (.iteration | tostring) == $iteration and
            (.provenance | type == "object" and
                (keys | sort) == ["harness_identity", "skill_identity", "spec_id"] and
                .spec_id == ($skill + "/evals/evals.json") and
                .skill_identity == $skill and
                (.harness_identity | type == "string" and length > 0 and length <= 192)) and
            (.run | type == "object" and
                (keys | sort) == ["duration_ms", "ended_at", "evidence_files", "output_files",
                    "redaction_status", "result", "run_id", "started_at", "status"] and
                (.run_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")) and
                (.status | IN("completed", "failed", "cancelled", "blocked")) and
                (.result | IN("passed", "failed", "cancelled", "blocked")) and
                (.started_at | type == "string" and length >= 20 and length <= 64) and
                (.ended_at | type == "string" and length >= 20 and length <= 64) and
                (.duration_ms | type == "number" and floor == . and . >= 0) and
                (.redaction_status | IN("clean", "redacted")) and
                (.output_files | type == "array" and length > 0 and
                    all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$"))) and
                (.evidence_files | type == "array" and
                    all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$"))))
        ' "$report_path" >/dev/null ||
            die "invalid materialized report: ${report_path#$PWD/}"
        while IFS= read -r referenced_file; do
            validate_evidence_file "$iteration_dir" "$referenced_file"
        done < <(jq -r '.run.output_files[], .run.evidence_files[]' "$report_path")
    done
}

validate_preparation_reports() {
    local iteration_dir="$1"
    local skill="$2"
    local iteration="$3"

    jq -e --arg skill "$skill" --arg iteration "$iteration" '
        (keys | sort) == ["delta", "iteration", "run_summary", "skill_name"] and
        .skill_name == $skill and (.iteration | tostring) == $iteration and
        .run_summary == {} and .delta == {}
    ' "${iteration_dir}/benchmark.json" >/dev/null ||
        die "preparation benchmark contains fabricated execution data: ${iteration_dir#$PWD/}/benchmark.json"
    jq -e --arg skill "$skill" --arg iteration "$iteration" '
        (keys | sort) == ["human_review", "iteration", "limitations", "recommendation", "skill_name"] and
        .skill_name == $skill and (.iteration | tostring) == $iteration and
        .human_review == [] and .limitations == [] and .recommendation == "hold"
    ' "${iteration_dir}/feedback.json" >/dev/null ||
        die "preparation feedback contains fabricated execution data: ${iteration_dir#$PWD/}/feedback.json"
    jq -e --arg skill "$skill" --arg iteration "$iteration" '
        (keys | sort) == ["cases", "iteration", "skill_name"] and
        .skill_name == $skill and (.iteration | tostring) == $iteration and
        .cases == {}
    ' "${iteration_dir}/grading-summary.json" >/dev/null ||
        die "preparation grading summary contains fabricated execution data: ${iteration_dir#$PWD/}/grading-summary.json"
}

validate_preparation_config() {
    local configuration_dir="$1"

    jq -e '
        (keys | sort) == ["duration_ms", "total_tokens"] and
        .duration_ms == null and .total_tokens == null
    ' "${configuration_dir}/timing.json" >/dev/null ||
        die "preparation timing report contains fabricated execution data: ${configuration_dir#$PWD/}/timing.json"
    jq -e '
        (keys | sort) == ["assertion_results", "summary"] and
        .assertion_results == [] and
        .summary == {passed: 0, failed: 0, total: 0, pass_rate: 0}
    ' "${configuration_dir}/grading.json" >/dev/null ||
        die "preparation grading report contains fabricated execution data: ${configuration_dir#$PWD/}/grading.json"
}

is_legacy_preparation_summary() {
    local iteration_dir="$1"

    jq -e '
        (keys | sort) as $keys |
        ([
            ["delta", "iteration", "run_summary", "skill_name"],
            ["delta", "iteration", "run_summary", "skill_name", "version"],
            ["calculation_note", "delta", "iteration", "run_summary",
                "runs_per_case", "skill_name", "version"],
            ["calculation_note", "iteration", "metrics", "runs_per_case",
                "skill_name", "version"]
        ] | any(.[]; . == $keys)) and
        (.version? == null or .version == 1) and
        (.iteration | type == "number" and floor == . and . > 0) and
        (.skill_name | type == "string" and length > 0) and
        ((.run_summary? // .metrics) | type == "object") and
        (.delta? // {} | type == "object")
    ' "${iteration_dir}/benchmark.json" >/dev/null 2>&1 || return 1
    jq -e '
        (keys | sort) as $keys |
        ([
            ["human_review", "iteration", "limitations", "recommendation", "skill_name"],
            ["iteration", "skill_name", "summary", "telemetry", "version", "workspace"],
            ["iteration", "skill_name", "summary", "telemetry", "version"],
            ["human_review", "iteration", "recommendation", "skill_name", "version"]
        ] | any(.[]; . == $keys)) and
        (.version? == null or .version == 1) and
        (.iteration | type == "number" and floor == . and . > 0) and
        (.skill_name | type == "string" and length > 0)
    ' "${iteration_dir}/feedback.json" >/dev/null 2>&1 || return 1
    jq -e '
        (keys | sort) as $keys |
        ([
            ["cases", "iteration", "skill_name"],
            ["cases", "iteration", "skill_name", "summary", "version"],
            ["calculation_note", "cases", "delta", "iteration", "run_summary",
                "skill_name", "version"],
            ["cases", "iteration", "runs_per_case", "skill_name", "version"],
            ["cases", "evidence_note", "iteration", "runs_per_case",
                "skill_name", "version"]
        ] | any(.[]; . == $keys)) and
        (.version? == null or .version == 1) and
        (.iteration | type == "number" and floor == . and . > 0) and
        (.skill_name | type == "string" and length > 0) and
        (.cases | type == "object")
    ' "${iteration_dir}/grading-summary.json" >/dev/null 2>&1 || return 1
}

main() {
    setopt localoptions null_glob

    local project_root base_path skills_path primary_skill_root workspace_dir skill_root skill_dir skill evals_dir spec
    local migration_map source_migration_map external_migration_map
    local map_source map_target resolved_skill workspace_skill_name
    local workspace_skill iteration_dir iteration_name manifest expected_ids manifest_ids iteration_state
    local workspace_entry discoverability_dir case_entry case_name configuration_dir configuration
    local current_iteration iteration_number
    local extra legacy_artifact candidate_root existing_root root_is_known
    local candidate matched_workspace_skill primary_spec alternate_spec
    local map_index visited_name historical_workspace historical_iteration
    local case_artifact_present is_current_iteration is_preparation_iteration
    local is_materialized_iteration materialized_execution legacy_preparation_iteration
    typeset -a workspace_skill_roots alternate_skill_roots active_skills visited

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
    primary_skill_root="$skills_path"
    # Repositories can contain multiple .agents/skills trees that share one workspace directory.
    workspace_skill_roots=("$primary_skill_root")
    alternate_skill_roots=()
    while IFS= read -r candidate_root; do
        root_is_known=false
        for existing_root in "${workspace_skill_roots[@]}"; do
            if [[ "$existing_root" == "$candidate_root" ]]; then
                root_is_known=true
                break
            fi
        done
        if [[ "$root_is_known" == false ]]; then
            workspace_skill_roots+=("$candidate_root")
            alternate_skill_roots+=("$candidate_root")
        fi
    done < <(find "$base_path" -type d -path '*/.agents/skills' -print)
    reject_duplicate_skill_names "$base_path" "${workspace_skill_roots[@]}"
    workspace_dir="${base_path}/.agents/eval-workspaces"
    source_migration_map="${task_source_dir}/migration-map.json"
    external_migration_map="${base_path}/home/.config/mise/tasks/ai/skills/evals/migration-map.json"
    migration_map=""
    if [[ "$base_path" == "$project_root" || "$base_path" == "${project_root}/home" ]]; then
        migration_map="$source_migration_map"
    elif [[ -e "$external_migration_map" || -L "$external_migration_map" ]]; then
        migration_map="$external_migration_map"
    fi
    migration_sources=()
    migration_targets=()
    legacy_preparation_skills=()
    if [[ -e "$migration_map" || -L "$migration_map" ]]; then
        [[ -f "$migration_map" && ! -L "$migration_map" ]] ||
            die "historical skill migration map must be a regular local file: ${migration_map#$base_path/}"
        valid_json "$migration_map"
        jq -e '
            ((keys | sort) == ["renames", "version"] or
                (keys | sort) == ["legacy_preparation", "renames", "version"]) and
            .version == 1 and
            (.renames | type == "array") and
            all(.renames[];
                (type == "object") and
                ((keys | sort) == ["from", "to"]) and
                (.from | type == "string" and test("^[a-z][a-z0-9-]*$")) and
                (.to | type == "string" and test("^[a-z][a-z0-9-]*$")) and
                (.from != .to)
            ) and
            ([.renames[].from] | length == (unique | length)) and
            ([.renames[].to] | length == (unique | length)) and
            (.legacy_preparation? == null or
                ((.legacy_preparation | type == "object") and
                    ((.legacy_preparation | keys | sort) == ["skills", "version"]) and
                    .legacy_preparation.version == 1 and
                    (.legacy_preparation.skills | type == "array" and
                        length > 0 and
                        all(.[]; type == "string" and test("^[a-z][a-z0-9-]*$"))) and
                    ([.legacy_preparation.skills[]] | length ==
                        (unique | length))))
        ' "$migration_map" >/dev/null ||
            die "invalid historical skill migration map: ${migration_map#$base_path/}"
        while IFS= read -r map_source; do
            [[ -n "$map_source" ]] && migration_sources+=("$map_source")
        done < <(jq -r '.renames[].from' "$migration_map")
        while IFS= read -r map_target; do
            [[ -n "$map_target" ]] && migration_targets+=("$map_target")
        done < <(jq -r '.renames[].to' "$migration_map")
        legacy_preparation_skills=()
        while IFS= read -r skill; do
            [[ -n "$skill" ]] && legacy_preparation_skills+=("$skill")
        done < <(jq -r '.legacy_preparation.skills[]?' "$migration_map")
    fi

    for map_source in "${migration_sources[@]}"; do
        visited=()
        resolved_skill="$map_source"
        while :; do
            for visited_name in "${visited[@]}"; do
                [[ "$visited_name" == "$resolved_skill" ]] ||
                    continue
                die "historical skill migration map contains a cycle at: ${resolved_skill}"
            done
            visited+=("$resolved_skill")
            map_index=1
            while (( map_index <= ${#migration_sources[@]} )); do
                [[ "${migration_sources[$map_index]}" == "$resolved_skill" ]] && break
                map_index=$((map_index + 1))
            done
            (( map_index <= ${#migration_sources[@]} )) || break
            resolved_skill="${migration_targets[$map_index]}"
        done
    done
    active_skills=()

    for skill_root in "$primary_skill_root"; do
        for skill_dir in "$skill_root"/*; do
            [[ -d "$skill_dir" ]] || continue
            skill="${skill_dir:t}"
            if is_migration_source "$skill"; then
                die "active skill uses historical name: ${skill}"
            fi
            evals_dir="${skill_dir}/evals"
            [[ -d "$evals_dir" ]] || continue
            spec="${evals_dir}/evals.json"
            validate_evaluation_spec "$skill_dir" "$skill" "$spec"
        done
    done

    for skill_root in "${workspace_skill_roots[@]}"; do
        for skill_dir in "$skill_root"/*; do
            [[ -d "$skill_dir" ]] || continue
            skill="${skill_dir:t}"
            if is_migration_source "$skill"; then
                die "active skill uses historical name: ${skill}"
            fi
            spec="${skill_dir}/evals/evals.json"
            [[ -f "$spec" ]] || continue
            active_skills+=("$skill")
        done
    done

    for map_source in "${migration_sources[@]}"; do
        resolved_skill="$(resolve_workspace_skill "$map_source")"
        matched_workspace_skill=false
        for skill in "${active_skills[@]}"; do
            [[ "$skill" == "$resolved_skill" ]] && matched_workspace_skill=true
        done
        [[ "$matched_workspace_skill" == true ]] ||
            die "historical skill migration target has no active evaluation spec: ${resolved_skill}"
    done

    if [[ ! -e "$workspace_dir" && ! -L "$workspace_dir" ]]; then
        print -- "Skill evaluation specs are valid. No repository-local workspaces found."
        return
    fi
    [[ -d "$workspace_dir" && ! -L "$workspace_dir" ]] ||
        die "evaluation workspace root must be a physical directory: ${workspace_dir#$base_path/}"
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
        [[ -e "$workspace_skill" || -L "$workspace_skill" ]] || continue
        [[ -d "$workspace_skill" && ! -L "$workspace_skill" ]] ||
            die "invalid evaluation workspace skill: ${workspace_skill#$base_path/}"
        workspace_skill_name="${workspace_skill:t}"
        resolved_skill="$(resolve_workspace_skill "$workspace_skill_name")"
        historical_workspace=false
        is_migration_source "$workspace_skill_name" && historical_workspace=true
        spec=""
        primary_spec=""
        alternate_spec=""
        matched_workspace_skill=false
        for skill_root in "$primary_skill_root" "${alternate_skill_roots[@]}"; do
            candidate="${skill_root}/${resolved_skill}/evals/evals.json"
            if [[ -e "$candidate" || -L "$candidate" ]]; then
                matched_workspace_skill=true
                validate_evaluation_spec "${candidate:h:h}" "$resolved_skill" "$candidate"
                if [[ "$skill_root" == "$primary_skill_root" ]]; then
                    primary_spec="$candidate"
                elif [[ -z "$alternate_spec" ]]; then
                    alternate_spec="$candidate"
                fi
            fi
        done
        if [[ "$matched_workspace_skill" != true ]]; then
            die "workspace has no matching skill spec; historical skill migration map is required: ${workspace_skill_name}"
        fi
        if [[ -n "$primary_spec" ]]; then
            spec="$primary_spec"
        elif [[ -n "$alternate_spec" ]]; then
            spec="$alternate_spec"
        else
            die "workspace has no selectable skill spec: ${workspace_skill_name}"
        fi
        expected_ids="$(jq -c '[.evals[].id]' "$spec")"

        for workspace_entry in "$workspace_skill"/*; do
            [[ -e "$workspace_entry" || -L "$workspace_entry" ]] || continue
            [[ -d "$workspace_entry" && ! -L "$workspace_entry" ]] ||
                die "invalid evaluation workspace entry: ${workspace_entry#$base_path/}"
            case "${workspace_entry:t}" in
                iteration-*) ;;
                discoverability)
                    discoverability_dir="$workspace_entry"
                    for extra in queries.json results.json; do
                        [[ -f "${discoverability_dir}/${extra}" && ! -L "${discoverability_dir}/${extra}" ]] ||
                            die "missing ${discoverability_dir#$base_path/}/${extra}"
                        valid_json "${discoverability_dir}/${extra}"
                    done
                    for extra in "${discoverability_dir}"/*; do
                        [[ -e "$extra" || -L "$extra" ]] || continue
                        case "${extra:t}" in
                            queries.json|results.json) ;;
                            *) die "invalid discoverability entry: ${extra#$base_path/}" ;;
                        esac
                    done
                    ;;
                *) die "invalid evaluation workspace entry: ${workspace_entry#$base_path/}" ;;
            esac
        done

        # The newest iteration is the physical iteration directory with the highest numeric suffix.
        current_iteration=0
        for workspace_entry in "$workspace_skill"/*; do
            [[ -e "$workspace_entry" || -L "$workspace_entry" ]] || continue
            case_name="${workspace_entry:t}"
            case "$case_name" in
                iteration-*)
                    [[ -d "$workspace_entry" && ! -L "$workspace_entry" ]] ||
                        die "invalid workspace directory: ${workspace_skill#$base_path/}/${case_name}"
                    [[ "$case_name" =~ '^iteration-[1-9][0-9]*$' ]] ||
                        die "invalid workspace directory: ${workspace_skill#$base_path/}/${case_name}"
                    iteration_number="${case_name#iteration-}"
                    [[ "$iteration_number" -gt "$current_iteration" ]] &&
                        current_iteration="$iteration_number"
                    ;;
            esac
        done

        for iteration_dir in "$workspace_skill"/iteration-*; do
            [[ -e "$iteration_dir" || -L "$iteration_dir" ]] || continue
            [[ -d "$iteration_dir" && ! -L "$iteration_dir" ]] ||
                die "invalid workspace directory: ${workspace_skill#$base_path/}/${iteration_dir:t}"
            iteration_name="${iteration_dir:t}"
            [[ "$iteration_name" =~ '^iteration-[1-9][0-9]*$' ]] ||
                die "invalid workspace directory: ${workspace_skill#$base_path/}/${iteration_name}"

            manifest="${iteration_dir}/manifest.json"
            [[ -f "$manifest" && ! -L "$manifest" ]] || die "missing ${manifest#$base_path/}"
            valid_json "$manifest"
            jq -e --arg skill "$workspace_skill_name" --arg iteration "${iteration_name#iteration-}" \
                '
                .version == 1 and
                .skill_name == $skill and
                (.iteration | tostring) == $iteration and
                (.case_ids | type == "array" and length > 0) and
                all(.case_ids[]; type == "string" and test("^[a-z][a-z0-9-]*$")) and
                ([.case_ids[]] | length == (unique | length)) and
                (.state? == null or
                    ((.state | type == "string") and
                        (.state == "historical" or .state == "preparation" or .state == "materialized")))
            ' "$manifest" >/dev/null ||
                die "invalid evaluation manifest: ${manifest#$base_path/}"
            manifest_ids="$(jq -c '.case_ids' "$manifest")"
            iteration_state="$(jq -r '.state // empty' "$manifest")"
            iteration_number="${iteration_name#iteration-}"
            case_artifact_present=false
            is_current_iteration=false
            is_preparation_iteration=false
            is_materialized_iteration=false
            materialized_execution=false
            historical_iteration=false
            legacy_preparation_iteration=false
            [[ "$iteration_number" -eq "$current_iteration" ]] &&
                is_current_iteration=true
            [[ "$iteration_state" == preparation ]] &&
                is_preparation_iteration=true
            [[ "$iteration_state" == materialized ]] &&
                is_materialized_iteration=true

            for extra in benchmark.json feedback.json grading-summary.json; do
                [[ -f "${iteration_dir}/${extra}" && ! -L "${iteration_dir}/${extra}" ]] ||
                    die "missing ${iteration_dir#$base_path/}/${extra}"
                valid_json "${iteration_dir}/${extra}"
                jq -e --arg skill "$workspace_skill_name" --arg iteration "${iteration_name#iteration-}" '
                    .skill_name == $skill and (.iteration | tostring) == $iteration
                ' "${iteration_dir}/${extra}" >/dev/null ||
                    die "invalid report identity: ${iteration_dir#$base_path/}/${extra}"
            done
            for case_entry in "$iteration_dir"/*; do
                [[ -e "$case_entry" || -L "$case_entry" ]] || continue
                case_name="${case_entry:t}"
                case "$case_name" in
                    manifest.json|benchmark.json|feedback.json|grading-summary.json) continue ;;
                esac
                [[ -d "$case_entry" && ! -L "$case_entry" ]] ||
                    die "evaluation case is not a physical directory: ${case_entry#$base_path/}"
                case_artifact_present=true
                jq -e -n --arg case_id "$case_name" --argjson expected "$manifest_ids" \
                    'any($expected[]; . == $case_id)' >/dev/null ||
                    die "workspace case is not in the evaluation manifest: ${case_entry#$base_path/}"

                for configuration_dir in "$case_entry"/*; do
                    [[ -e "$configuration_dir" || -L "$configuration_dir" ]] || continue
                    [[ -d "$configuration_dir" && ! -L "$configuration_dir" ]] ||
                        die "evaluation configuration is not a physical directory: ${configuration_dir#$base_path/}"
                    case "${configuration_dir:t}" in
                        with_skill|old_skill) ;;
                        *) die "invalid evaluation configuration: ${configuration_dir#$base_path/}" ;;
                    esac
                done
            done

            if [[ "$iteration_state" == historical ]]; then
                [[ "$historical_workspace" == true ]] ||
                    die "historical evaluation state requires explicit migration metadata: ${manifest#$base_path/}"
                historical_iteration=true
            elif [[ -z "$iteration_state" && "$historical_workspace" == true ]]; then
                historical_iteration=true
            elif [[ -z "$iteration_state" && "$case_artifact_present" == false ]] &&
                is_legacy_preparation_skill "$workspace_skill_name" &&
                is_legacy_preparation_summary "$iteration_dir"; then
                legacy_preparation_iteration=true
                historical_iteration=true
            fi

            if [[ "$historical_iteration" == false &&
                "$is_current_iteration" == true &&
                "$manifest_ids" != "$expected_ids" ]]; then
                die "current evaluation manifest does not match the evaluation spec: ${manifest#$base_path/}"
            fi

            if [[ "$case_artifact_present" == false &&
                "$historical_iteration" == true ]]; then
                print -- "Accepted legacy historical evaluation iteration: ${iteration_dir#$base_path/}"
            fi

            if [[ "$case_artifact_present" == false &&
                "$historical_iteration" == false ]]; then
                die "evaluation iteration has no case artifacts or explicit historical state: ${iteration_dir#$base_path/}"
            fi

            if [[ "$historical_iteration" == false &&
                ( "$is_current_iteration" == true ||
                    "$is_preparation_iteration" == true ||
                    "$is_materialized_iteration" == true ) ]] ||
                [[ "$historical_iteration" == true &&
                    "$case_artifact_present" == true ]]; then
                while IFS= read -r case_name; do
                    case_entry="${iteration_dir}/${case_name}"
                    [[ -e "$case_entry" || -L "$case_entry" ]] ||
                        die "missing evaluation case directory: ${case_entry#$base_path/}"
                    [[ -d "$case_entry" && ! -L "$case_entry" ]] ||
                        die "evaluation case is not a physical directory: ${case_entry#$base_path/}"
                    for configuration in with_skill old_skill; do
                        configuration_dir="${case_entry}/${configuration}"
                        [[ -d "$configuration_dir" && ! -L "$configuration_dir" ]] ||
                            die "missing evaluation configuration: ${configuration_dir#$base_path/}"
                        [[ -d "${configuration_dir}/outputs" && ! -L "${configuration_dir}/outputs" ]] ||
                            die "missing output directory: ${configuration_dir#$base_path/}/outputs"
                        for extra in timing.json grading.json; do
                            [[ -f "${configuration_dir}/${extra}" && ! -L "${configuration_dir}/${extra}" ]] ||
                                die "missing ${configuration_dir#$base_path/}/${extra}"
                            valid_json "${configuration_dir}/${extra}"
                        done
                        if [[ "$is_preparation_iteration" == true ]]; then
                            validate_preparation_config "$configuration_dir"
                        else
                            materialized_execution=true
                            validate_materialized_config "$configuration_dir" \
                                "$workspace_skill_name" "$iteration_number" "$case_name" "$configuration"
                        fi
                    done
                done < <(jq -r '.[]' <<<"$manifest_ids")
                if [[ "$materialized_execution" == true ]]; then
                    validate_materialized_reports "$iteration_dir" \
                        "$workspace_skill_name" "$iteration_number"
                fi
                if [[ "$is_preparation_iteration" == true ]]; then
                    validate_preparation_reports "$iteration_dir" \
                        "$workspace_skill_name" "$iteration_number"
                fi
            fi
        done
    done

    print -- "Skill evaluation specs and repository-local workspaces are valid."
}

main "$@"
