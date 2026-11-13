#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

materialize_iteration() {
    local fixture="$1"
    local iteration="$2"
    local complete="$3"
    local state="${4:-materialized}"
    local iteration_dir="$fixture/.agents/eval-workspaces/demo/iteration-${iteration}"
    local configuration run_id

    jq --arg state "$state" '.state = $state' "$iteration_dir/manifest.json" >"$fixture/manifest-${iteration}.json"
    mv "$fixture/manifest-${iteration}.json" "$iteration_dir/manifest.json"
    for configuration in with_skill old_skill; do
        run_id="run-${iteration}-${configuration}"
        mkdir -p "$iteration_dir/example-case/$configuration/outputs"
        mkdir -p "$iteration_dir/example-case/$configuration/evidence"
        printf '%s\n' "output ${run_id}" >"$iteration_dir/example-case/$configuration/outputs/run.txt"
        printf '%s\n' "evidence ${run_id}" >"$iteration_dir/example-case/$configuration/evidence/run.txt"
        jq -n \
            --arg run_id "$run_id" \
            --arg configuration "$configuration" '{
                case_id: "example-case",
                configuration: $configuration,
                duration_ms: 1,
                ended_at: "2026-01-01T00:00:01Z",
                evidence_files: ["evidence/run.txt"],
                harness_identity: "test-harness",
                output_files: ["outputs/run.txt"],
                redaction_status: "clean",
                result: "passed",
                run_id: $run_id,
                skill_identity: "demo",
                spec_id: "demo/evals/evals.json",
                started_at: "2026-01-01T00:00:00Z",
                status: "completed",
                total_tokens: 1
            }' >"$iteration_dir/example-case/$configuration/timing.json"
        jq -n \
            --arg run_id "$run_id" \
            --arg configuration "$configuration" '{
                assertion_results: [{
                    evidence: ["evidence/run.txt"],
                    id: "assertion-1",
                    status: "passed"
                }],
                case_id: "example-case",
                configuration: $configuration,
                redaction_status: "clean",
                result: "passed",
                run_id: $run_id,
                status: "completed"
            }' >"$iteration_dir/example-case/$configuration/grading.json"
    done
    if [[ "$complete" != true ]]; then
        rm -rf "$iteration_dir/example-case/with_skill/outputs"
    fi
}

main() {
    local fixture output_before validation_output
    local task_root="$__root_dir"
    local mise_config="$__test_mise_config_dir"
    local workspace_root

    fixture="$(test_fixture_dir skill-evals-retire)" || fail "could not create fixture directory"
    trap "rm -rf -- '$fixture'" EXIT
    workspace_root="$fixture/.agents/eval-workspaces/demo"
    mkdir -p "$fixture/.agents/skills/demo/evals"
    printf '%s\n' '# Demo skill' >"$fixture/.agents/skills/demo/SKILL.md"
    git -C "$fixture" init -q

    output_before="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire --help
    )" || fail "retire task help failed"
    print -r -- "$output_before" | grep -qF -- "--skill <skill>" ||
        fail "retire task help omitted --skill"
    print -r -- "$output_before" | grep -qF -- "--iteration <number>" ||
        fail "retire task help omitted --iteration"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:init \
        --base-path "$fixture" --skill demo >/dev/null ||
        fail "could not initialize the evaluation specification"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "could not prepare iteration 1"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 2 >/dev/null ||
        fail "could not prepare iteration 2"
    materialize_iteration "$fixture" 1 false preparation
    jq -e '.state == "preparation"' "$workspace_root/iteration-1/manifest.json" >/dev/null ||
        fail "retirement fixture did not preserve preparation state"
    output_before="$(cat "$workspace_root/iteration-1/example-case/old_skill/evidence/run.txt")"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
        --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "retire task rejected an incomplete preparation iteration after a newer iteration"
    jq -e '
        .state == "historical" and
        .history_reason == "retired-materialized-incomplete"
    ' "$workspace_root/iteration-1/manifest.json" >/dev/null ||
        fail "retire task did not persist the canonical historical marker"
    [[ "$(cat "$workspace_root/iteration-1/example-case/old_skill/evidence/run.txt")" == "$output_before" ]] ||
        fail "retire task changed raw evidence"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
        --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "retire task was not idempotent"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
        --base-path "$fixture" >/dev/null ||
        fail "validator rejected the retired incomplete iteration"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 3 >/dev/null ||
        fail "could not prepare iteration 3"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 4 >/dev/null ||
        fail "could not prepare iteration 4"
    materialize_iteration "$fixture" 3 true
    validation_output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
            --base-path "$fixture" --skill demo --iteration 3 2>&1
    )" && fail "retire task accepted a complete iteration"
    print -r -- "$validation_output" | grep -qF "iteration is complete" ||
        fail "complete-iteration rejection was not explained"

    validation_output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
            --base-path "$fixture" --skill demo --iteration 4 2>&1
    )" && fail "retire task accepted the current/latest iteration"
    print -r -- "$validation_output" | grep -qF "current/latest" ||
        fail "latest preparation rejection was not explained"

    jq '.state = "historical" | .history_reason = "unsafe-transition"' \
        "$workspace_root/iteration-3/manifest.json" >"$fixture/unsafe-manifest.json"
    mv "$fixture/unsafe-manifest.json" "$workspace_root/iteration-3/manifest.json"
    validation_output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
            --base-path "$fixture" --skill demo --iteration 3 2>&1
    )" && fail "retire task accepted an unsafe repeated transition"
    print -r -- "$validation_output" | grep -qF "unsafe historical state" ||
        fail "unsafe-transition rejection was not explained"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 5 >/dev/null ||
        fail "could not prepare iteration 5"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 6 >/dev/null ||
        fail "could not prepare iteration 6"
    materialize_iteration "$fixture" 5 false
    printf '%s\n' '{}' >"$workspace_root/iteration-5/example-case/with_skill/timing.json"
    validation_output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:retire \
            --base-path "$fixture" --skill demo --iteration 5 2>&1
    )" && fail "retire task accepted malformed metadata"
    print -r -- "$validation_output" | grep -qF "invalid materialized timing report" ||
        fail "malformed metadata rejection was not explained"
}

main "$@"
