#!/usr/bin/env zsh
#MISE description="Retire an incomplete historical skill evaluation iteration"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--skill <skill>" help="Skill directory name"
#USAGE flag "--iteration <number>" help="Evaluation iteration number"
#USAGE flag "--base-path <path>" help="Repository directory; defaults to the current project root"
#USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

is_physical_directory() {
    [[ -d "$1" && ! -L "$1" ]]
}

is_regular_file() {
    [[ -f "$1" && ! -L "$1" ]]
}

validate_evidence_file() {
    local configuration_dir="$1"
    local referenced_file="$2"
    local allow_missing="$3"
    local canonical_root canonical_path

    [[ "$referenced_file" != /* && "$referenced_file" != *\\* ]] ||
        return 2
    [[ "$referenced_file" != "." && "$referenced_file" != ".." &&
        "$referenced_file" != ./* && "$referenced_file" != ../* &&
        "$referenced_file" != */./* && "$referenced_file" != */../* &&
        "$referenced_file" != */. && "$referenced_file" != */.. ]] ||
        return 2
    canonical_root="$(cd "$configuration_dir" && pwd -P)" || return 2
    canonical_path="$(realpath "${configuration_dir}/${referenced_file}" 2>/dev/null || true)"
    if [[ -z "$canonical_path" ]]; then
        [[ "$allow_missing" == true ]] && return 1
        return 2
    fi
    [[ "$canonical_path" == "$canonical_root"/* ]] || return 2
    [[ -f "$canonical_path" ]] || return 2
    return 0
}

validate_materialized_metadata() {
    local configuration_dir="$1"
    local skill="$2"
    local case_id="$3"
    local configuration="$4"
    local spec="$5"
    local timing="${configuration_dir}/timing.json"
    local grading="${configuration_dir}/grading.json"
    local expected_assertions

    expected_assertions="$(
        jq -c --arg case "$case_id" '
            (.evals[] | select(.id == $case) | (.assertions // [])) |
            to_entries | map("assertion-\(.key + 1)")
        ' "$spec" 2>/dev/null
    )" || die "malformed evaluation specification: ${spec}"

    jq -e --arg skill "$skill" --arg case "$case_id" --arg configuration "$configuration" '
        (keys | sort) == [
            "case_id", "configuration", "duration_ms", "ended_at", "evidence_files",
            "harness_identity", "output_files", "redaction_status", "result", "run_id",
            "skill_identity", "spec_id", "started_at", "status", "total_tokens"
        ] and
        .case_id == $case and .configuration == $configuration and
        (.run_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")) and
        .spec_id == ($skill + "/evals/evals.json") and .skill_identity == $skill and
        (.harness_identity | type == "string" and length > 0 and length <= 192) and
        (.status == "completed" or .status == "failed" or .status == "cancelled" or .status == "blocked") and
        (.result == "passed" or .result == "failed" or .result == "cancelled" or .result == "blocked") and
        (.started_at | type == "string" and length >= 20 and length <= 64) and
        (.ended_at | type == "string" and length >= 20 and length <= 64) and
        (.duration_ms | type == "number" and floor == . and . >= 0) and
        (.total_tokens | type == "number" and floor == . and . >= 0) and
        (.redaction_status == "clean" or .redaction_status == "redacted") and
        (.output_files | type == "array" and length > 0 and all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$"))) and
        (.evidence_files | type == "array" and all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$")))
    ' "$timing" >/dev/null ||
        die "invalid materialized timing report: ${timing}"

    jq -e --arg case "$case_id" --arg configuration "$configuration" \
        --argjson expected "$expected_assertions" '
        (keys | sort) == [
            "assertion_results", "case_id", "configuration", "redaction_status",
            "result", "run_id", "status"
        ] and
        .case_id == $case and .configuration == $configuration and
        (.run_id | type == "string" and length > 0 and length <= 128) and
        (.status == "completed" or .status == "failed" or .status == "cancelled" or .status == "blocked") and
        (.result == "passed" or .result == "failed" or .result == "cancelled" or .result == "blocked") and
        (.redaction_status == "clean" or .redaction_status == "redacted") and
        (.assertion_results | type == "array") and
        (.assertion_results | map(
                (keys | sort) == ["evidence", "id", "status"] and
                (.id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")) and
                (.status == "passed" or .status == "failed" or .status == "blocked") and
                (.evidence | type == "array" and length > 0 and all(.[]; type == "string" and test("^[A-Za-z0-9._/-]+$")))
            ) | all) and
        ([.assertion_results[].id] == $expected or
            ([.assertion_results[].id] == ($expected | map(sub("^assertion-"; "a")))))
    ' "$grading" >/dev/null ||
        die "invalid materialized grading report: ${grading}"

    jq -n -e --slurpfile timing "$timing" --slurpfile grading "$grading" \
        '$timing[0].run_id == $grading[0].run_id' >/dev/null ||
        die "materialized timing and grading run IDs do not match: ${configuration_dir}"
}

retired_configuration_is_incomplete() {
    local configuration_dir="$1"
    local referenced_file
    local incomplete=false
    local output_dir="${configuration_dir}/outputs"

    if is_physical_directory "$output_dir"; then
        while IFS= read -r referenced_file; do
            if validate_evidence_file "$configuration_dir" "$referenced_file" true; then
                :
            else
                case "$?" in
                    1) incomplete=true ;;
                    *) die "invalid materialized output reference: ${configuration_dir}" ;;
                esac
            fi
        done < <(jq -r '.output_files[]' "${configuration_dir}/timing.json")
    else
        [[ ! -e "$output_dir" && ! -L "$output_dir" ]] ||
            die "retired historical output directory is not physical: ${output_dir}"
        incomplete=true
    fi

    while IFS= read -r referenced_file; do
        if validate_evidence_file "$configuration_dir" "$referenced_file" true; then
            :
        else
            case "$?" in
                1) incomplete=true ;;
                *) die "invalid materialized evidence reference: ${configuration_dir}" ;;
            esac
        fi
    done < <(jq -r '.evidence_files[]' "${configuration_dir}/timing.json")
    while IFS= read -r referenced_file; do
        if validate_evidence_file "$configuration_dir" "$referenced_file" true; then
            :
        else
            case "$?" in
                1) incomplete=true ;;
                *) die "invalid grading evidence reference: ${configuration_dir}" ;;
            esac
        fi
    done < <(jq -r '.assertion_results[].evidence[]' "${configuration_dir}/grading.json")

    [[ "$incomplete" == true ]]
}

main() {
    local project_root base_path skills_path skill iteration skill_dir spec
    local workspace_root iteration_dir manifest manifest_state history_reason
    local case_id case_dir configuration configuration_dir
    local manifest_ids latest_iteration iteration_name report iteration_dir_candidate
    local incomplete=false temp_manifest already_retired=false
    local usage_skill="${usage_skill:-}"
    local usage_iteration="${usage_iteration:-}"
    local usage_base_path="${usage_base_path:-}"
    local usage_skills_path="${usage_skills_path:-}"

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"

    base_path="$usage_base_path"
    [[ -n "$base_path" ]] || base_path="$project_root"
    [[ "$base_path" == /* ]] || base_path="${project_root}/${base_path}"
    base_path="$(cd "$base_path" 2>/dev/null && pwd -P)" ||
        die "base path '${usage_base_path:-.}' does not exist"
    project_root="$(git -C "$base_path" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "base path is not inside a git repository"

    skills_path="$usage_skills_path"
    [[ -n "$skills_path" ]] || skills_path="${base_path}/.agents/skills"
    [[ "$skills_path" == /* ]] || skills_path="${base_path}/${skills_path}"
    skills_path="$(cd "$skills_path" 2>/dev/null && pwd -P)" ||
        die "skills path '${usage_skills_path:-.agents/skills}' does not exist"

    skill="$usage_skill"
    [[ "$skill" =~ '^[a-z][a-z0-9-]*$' ]] || die "--skill must be a descriptive kebab-case skill name"
    [[ "$usage_iteration" =~ '^[1-9][0-9]*$' ]] || die "--iteration must be a positive integer"
    iteration="$usage_iteration"

    skill_dir="${skills_path}/${skill}"
    spec="${skill_dir}/evals/evals.json"
    is_physical_directory "$skill_dir" || die "skill not found: ${skill}"
    is_regular_file "$spec" || die "evaluation specification not found for skill: ${skill}"
    jq -e --arg skill "$skill" '
        (keys | sort) == ["evals", "skill_name"] and .skill_name == $skill and
        (.evals | type == "array" and length > 0) and
        all(.evals[]; .id | type == "string")
    ' "$spec" >/dev/null || die "invalid evaluation specification: ${spec}"

    workspace_root="${project_root}/.agents/eval-workspaces/${skill}"
    iteration_dir="${workspace_root}/iteration-${iteration}"
    manifest="${iteration_dir}/manifest.json"
    is_physical_directory "$workspace_root" || die "evaluation workspace not found: ${workspace_root}"
    is_physical_directory "$iteration_dir" || die "evaluation iteration not found: ${iteration_dir}"
    is_regular_file "$manifest" || die "missing evaluation manifest: ${manifest}"

    manifest_state="$(jq -r '.state // empty' "$manifest" 2>/dev/null)" ||
        die "invalid evaluation manifest: ${manifest}"
    history_reason="$(jq -r '.history_reason // empty' "$manifest" 2>/dev/null)" ||
        die "invalid evaluation manifest: ${manifest}"
    if [[ "$manifest_state" == historical && "$history_reason" == retired-materialized-incomplete ]]; then
        already_retired=true
    elif [[ "$manifest_state" == historical || -n "$history_reason" ]]; then
        die "evaluation iteration has an unsafe historical state: ${manifest}"
    fi

    if [[ "$already_retired" != true ]]; then
        latest_iteration=0
        for iteration_dir_candidate in "${workspace_root}"/iteration-*; do
            [[ -e "$iteration_dir_candidate" || -L "$iteration_dir_candidate" ]] || continue
            iteration_name="${iteration_dir_candidate:t}"
            [[ "$iteration_name" =~ '^iteration-[1-9][0-9]*$' ]] ||
                die "invalid evaluation workspace entry: ${iteration_dir_candidate}"
            is_physical_directory "$iteration_dir_candidate" ||
                die "invalid evaluation workspace directory: ${iteration_dir_candidate}"
            (( ${iteration_name#iteration-} > latest_iteration )) &&
                latest_iteration="${iteration_name#iteration-}"
        done
        [[ "$iteration" -lt "$latest_iteration" ]] ||
            die "cannot retire the current/latest evaluation iteration: ${iteration_dir}"
    fi

    jq -e --arg skill "$skill" --argjson iteration "$iteration" '
        ((keys | sort) == ["case_ids", "iteration", "skill_name", "version", "workspace"] or
            (keys | sort) == ["case_ids", "iteration", "skill_name", "state", "version", "workspace"] or
            (keys | sort) == ["case_ids", "history_reason", "iteration", "skill_name", "state", "version", "workspace"]) and
        .version == 1 and .skill_name == $skill and .iteration == $iteration and
        (.case_ids | type == "array" and length > 0 and all(.[]; type == "string" and test("^[a-z][a-z0-9-]*$"))) and
        ([.case_ids[]] | length == (unique | length)) and
        (.state == null or .state == "materialized" or
            (.state == "historical" and .history_reason == "retired-materialized-incomplete"))
    ' "$manifest" >/dev/null || die "invalid evaluation manifest: ${manifest}"

    [[ "$already_retired" == true || "$manifest_state" != preparation ]] ||
        die "cannot retire a preparation evaluation iteration: ${iteration_dir}"

    manifest_ids="$(jq -c '.case_ids' "$manifest")"
    jq -e --argjson ids "$manifest_ids" '
        . as $spec |
        all($ids[]; . as $id | ($spec.evals | any(.[]; .id == $id)))
    ' "$spec" >/dev/null || die "evaluation manifest contains cases not present in the evaluation specification: ${manifest}"
    for case_id in ${(f)"$(jq -r '.[]' <<<"$manifest_ids")"}; do
        case_dir="${iteration_dir}/${case_id}"
        is_physical_directory "$case_dir" || die "missing evaluation case directory: ${case_dir}"
        for configuration in with_skill old_skill; do
            configuration_dir="${case_dir}/${configuration}"
            is_physical_directory "$configuration_dir" ||
                die "missing evaluation configuration: ${configuration_dir}"
            for report in timing.json grading.json; do
                is_regular_file "${configuration_dir}/${report}" ||
                    die "missing evaluation metadata: ${configuration_dir}/${report}"
            done
            validate_materialized_metadata "$configuration_dir" "$skill" "$case_id" "$configuration" "$spec"
            if retired_configuration_is_incomplete "$configuration_dir"; then
                incomplete=true
            fi
        done
    done

    for case_dir in "${iteration_dir}"/*; do
        [[ -e "$case_dir" || -L "$case_dir" ]] || continue
        case_id="${case_dir:t}"
        [[ "$case_id" == manifest.json || "$case_id" == benchmark.json ||
            "$case_id" == feedback.json || "$case_id" == grading-summary.json ]] && continue
        [[ "$case_id" == iteration-* ]] && continue
        print -r -- "$manifest_ids" | jq -e --arg case "$case_id" 'index($case) != null' >/dev/null ||
            die "workspace case is not in the evaluation manifest: ${case_dir}"
    done
    [[ "$incomplete" == true ]] ||
        die "evaluation iteration is complete; only incomplete iterations may be retired: ${iteration_dir}"

    if [[ "$already_retired" == true ]]; then
        print -- "Evaluation iteration is already retired: ${iteration_dir#$project_root/}"
        return
    fi

    temp_manifest="${manifest}.retire.$$"
    trap 'rm -f -- "${temp_manifest:-}"' EXIT
    jq '.state = "historical" | .history_reason = "retired-materialized-incomplete"' \
        "$manifest" >"$temp_manifest" || die "could not update evaluation manifest: ${manifest}"
    mv "$temp_manifest" "$manifest" || die "could not install evaluation manifest: ${manifest}"
    trap - EXIT
    print -- "Retired incomplete evaluation iteration: ${iteration_dir#$project_root/}"
}

main "$@"
