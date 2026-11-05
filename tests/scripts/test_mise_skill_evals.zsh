#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    local fixture skill_dir spec_dir workspace_parent workspace_dir workspace_root case_path
    local materialized_iteration materialized_case retired_iteration configuration
    local migration_map historical_workspace global_skill_dir global_workspace_dir
    local validation_output missing_map_base renamed_workspace canonical_output fixture_real
    local collision_primary_dir collision_alternate_dir
    local selection_skill_dir selection_spec_dir selection_workspace_root
    local selection_active selection_retired selection_configuration

    fixture="$(test_fixture_dir skill-evals)" || fail "could not create fixture directory"
    fixture_real="$(cd "$fixture" && pwd -P)"
    trap "rm -rf -- '$fixture'" EXIT
    skill_dir="$fixture/.agents/skills/demo"
    spec_dir="$skill_dir/evals"
    workspace_parent="$fixture/.agents/eval-workspaces"
    workspace_root="$workspace_parent/demo"
    workspace_dir="$workspace_root/iteration-1"
    migration_map="$fixture/home/.config/mise/tasks/ai/skills/evals/migration-map.json"
    mkdir -p "$skill_dir"
    mkdir -p "${migration_map:h}"
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF
    git -C "$fixture" init -q
    printf '%s\n' '# Demo skill' >"$skill_dir/SKILL.md"

    mise run ai:skills:evals:init --base-path "$fixture" --skill demo >/dev/null ||
        fail "init task rejected a valid skill"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "prepare task rejected a valid evaluation specification"
    [[ -f "$workspace_dir/manifest.json" ]] || fail "prepare task did not create a manifest"
    jq -e '
        .version == 1 and
        .skill_name == "demo" and
        .iteration == 1 and
        .case_ids == ["example-case"] and
        .workspace == ".agents/eval-workspaces/demo" and
        .state == "preparation"
    ' "$workspace_dir/manifest.json" >/dev/null ||
        fail "prepare task did not preserve manifest fields and persist preparation state"
    [[ -f "$workspace_dir/example-case/with_skill/timing.json" ]] ||
        fail "prepare task did not create with_skill timing metadata"
    [[ -f "$workspace_dir/example-case/old_skill/grading.json" ]] ||
        fail "prepare task did not create old_skill grading metadata"

    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a valid fixture"

    git -C "$fixture" add -A
    git -C "$fixture" -c user.name=test -c user.email=test@example.com \
        -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm baseline ||
        fail "could not create fixture baseline"
    printf '%s\n' 'unrelated change' >"$fixture/README.md"
    validation_output="$(mise run ai:skills:evals:validate \
        --base-path "$fixture" --changed-only 2>&1)" ||
        fail "changed-only validator rejected unrelated changes"
    print -r -- "$validation_output" | grep -qF "No skill evaluation files changed" ||
        fail "changed-only validator did not skip unrelated changes"
    rm "$fixture/README.md"
    printf '%s\n' 'skill change' >"$skill_dir/notes.txt"
    validation_output="$(mise run ai:skills:evals:validate \
        --base-path "$fixture" --changed-only 2>&1)" ||
        fail "changed-only validator rejected a changed skill"
    if print -r -- "$validation_output" | grep -qF "No skill evaluation files changed"; then
        fail "changed-only validator skipped a changed skill"
    fi
    rm "$skill_dir/notes.txt"

    canonical_output="$(mise run ai:skills:evals:prepare \
        --base-path "$fixture/home" --skills-path "$fixture/.agents/skills" \
        --skill demo --iteration 99 --dry-run 2>&1)" ||
        fail "prepare task rejected a base path with a separate skill source"
    print -r -- "$canonical_output" |
        grep -qxF -- "Would create ${fixture_real}/.agents/eval-workspaces/demo/iteration-99" ||
        fail "prepare task did not use the repository-root evaluation workspace"

    mv "$migration_map" "$fixture/migration-map-absent.json"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a repository without a migration map"
    mv "$fixture/migration-map-absent.json" "$migration_map"

    mv "$workspace_parent" "$fixture/workspace-root-directory"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected an absent workspace root"
    mv "$fixture/workspace-root-directory" "$workspace_parent"

    mv "$workspace_parent" "$fixture/workspace-root-directory"
    printf '%s\n' 'not a directory' >"$workspace_parent"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a non-directory workspace root"
    fi
    rm "$workspace_parent"
    mv "$fixture/workspace-root-directory" "$workspace_parent"

    printf '%s\n' 'stale workspace file' >"$workspace_root/stale.txt"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a direct file under the skill workspace"
    fi
    rm "$workspace_root/stale.txt"

    printf '%s\n' 'stale discoverability file' >"$workspace_root/discoverability"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a discoverability file under the skill workspace"
    fi
    rm "$workspace_root/discoverability"

    historical_workspace="$fixture/.agents/eval-workspaces/legacy-demo/iteration-1"
    mkdir -p "$historical_workspace"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        if [[ "$extra" == manifest.json ]]; then
            jq --arg skill legacy-demo '.skill_name = $skill | del(.state)' \
                "$workspace_dir/$extra" >"$historical_workspace/$extra"
        else
            jq --arg skill legacy-demo '.skill_name = $skill' \
                "$workspace_dir/$extra" >"$historical_workspace/$extra"
        fi
    done
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" 2>&1)" ||
        fail "validator rejected a clean historical workspace through the rename map"
    print -r -- "$validation_output" | grep -qF "Accepted legacy historical evaluation iteration" ||
        fail "validator did not classify the summary-only workspace as legacy historical"

    missing_map_base="$fixture/nested-base"
    mkdir -p "$missing_map_base/.agents/skills/demo/evals"
    mkdir -p "$missing_map_base/.agents/eval-workspaces/legacy-demo/iteration-1"
    git -C "$missing_map_base" init -q
    cp "$spec_dir/evals.json" "$missing_map_base/.agents/skills/demo/evals/evals.json"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        if [[ "$extra" == manifest.json ]]; then
            jq --arg skill legacy-demo '.skill_name = $skill | del(.state)' \
                "$workspace_dir/$extra" \
                >"$missing_map_base/.agents/eval-workspaces/legacy-demo/iteration-1/$extra"
        else
            jq --arg skill legacy-demo '.skill_name = $skill' \
                "$workspace_dir/$extra" \
                >"$missing_map_base/.agents/eval-workspaces/legacy-demo/iteration-1/$extra"
        fi
    done
    if validation_output="$(mise run ai:skills:evals:validate --base-path "$missing_map_base" 2>&1)"; then
        fail "validator accepted a historical workspace without migration metadata"
    fi
    print -r -- "$validation_output" | grep -qF "historical skill migration map is required" ||
        fail "validator did not explain that historical migration metadata is required"
    rm -rf "$missing_map_base"

    cp -R "$workspace_dir" "$fixture/historical-state"
    jq '.state = "historical"' "$fixture/historical-state/manifest.json" \
        >"$fixture/historical-state-manifest.json"
    mv "$fixture/historical-state-manifest.json" \
        "$fixture/historical-state/manifest.json"
    mkdir -p "$workspace_root/iteration-99"
    cp "$fixture/historical-state/manifest.json" "$workspace_root/iteration-99/manifest.json"
    cp "$fixture/historical-state/benchmark.json" "$workspace_root/iteration-99/benchmark.json"
    cp "$fixture/historical-state/feedback.json" "$workspace_root/iteration-99/feedback.json"
    cp "$fixture/historical-state/grading-summary.json" "$workspace_root/iteration-99/grading-summary.json"
    jq '.iteration = 99' "$workspace_root/iteration-99/manifest.json" \
        >"$fixture/historical-state-manifest-99.json"
    mv "$fixture/historical-state-manifest-99.json" "$workspace_root/iteration-99/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted arbitrary historical state without migration metadata"
    fi
    rm -rf "$workspace_root/iteration-99" "$fixture/historical-state"

    retired_iteration="$workspace_root/iteration-99"
    mkdir -p "$retired_iteration"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        cp "$workspace_dir/$extra" "$retired_iteration/$extra"
    done
    jq '.iteration = 99 | .state = "historical" | .history_reason = "retired-materialized-incomplete"' \
        "$retired_iteration/manifest.json" >"$fixture/manifest-retired.json"
    mv "$fixture/manifest-retired.json" "$retired_iteration/manifest.json"
    jq --argjson iteration 99 '.iteration = $iteration' \
        "$retired_iteration/benchmark.json" >"$fixture/benchmark-retired.json"
    mv "$fixture/benchmark-retired.json" "$retired_iteration/benchmark.json"
    jq --argjson iteration 99 '.iteration = $iteration' \
        "$retired_iteration/feedback.json" >"$fixture/feedback-retired.json"
    mv "$fixture/feedback-retired.json" "$retired_iteration/feedback.json"
    jq --argjson iteration 99 '.iteration = $iteration' \
        "$retired_iteration/grading-summary.json" >"$fixture/grading-retired.json"
    mv "$fixture/grading-retired.json" "$retired_iteration/grading-summary.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a retired historical iteration without case metadata"
    fi

    jq 'del(.history_reason)' "$retired_iteration/manifest.json" \
        >"$fixture/manifest-retired-missing-reason.json"
    mv "$fixture/manifest-retired-missing-reason.json" "$retired_iteration/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a retired historical iteration without its reason"
    fi
    jq '.history_reason = "arbitrary-history"' "$retired_iteration/manifest.json" \
        >"$fixture/manifest-retired-wrong-reason.json"
    mv "$fixture/manifest-retired-wrong-reason.json" "$retired_iteration/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an arbitrary historical reason"
    fi
    rm -rf "$retired_iteration"

    jq '.renames = [{from: "legacy-demo", to: "unknown-demo"}]' "$migration_map" \
        >"$fixture/migration-map-invalid.json"
    mv "$fixture/migration-map-invalid.json" "$migration_map"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a migration map with an unknown target"
    fi
    jq '.renames = [{from: "legacy-demo", to: "other-demo"}, {from: "other-demo", to: "legacy-demo"}]' \
        "$migration_map" >"$fixture/migration-map-cycle.json"
    mv "$fixture/migration-map-cycle.json" "$migration_map"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a migration map cycle"
    fi
    jq '.renames = [{from: "legacy-demo", to: "demo"}, {from: "other-demo", to: "demo"}]' \
        "$migration_map" >"$fixture/migration-map-duplicate-target.json"
    mv "$fixture/migration-map-duplicate-target.json" "$migration_map"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a migration map with duplicate endpoints"
    fi
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF

    rm -rf "$fixture/.agents/eval-workspaces/legacy-demo"
    jq '.renames = [{from: "old-a", to: "old-b"}, {from: "old-b", to: "demo"}]' \
        "$migration_map" >"$fixture/migration-map-chain.json"
    mv "$fixture/migration-map-chain.json" "$migration_map"
    historical_workspace="$fixture/.agents/eval-workspaces/old-a/iteration-1"
    mkdir -p "$historical_workspace"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        if [[ "$extra" == manifest.json ]]; then
            jq --arg skill old-a '.skill_name = $skill | del(.state)' \
                "$workspace_dir/$extra" >"$historical_workspace/$extra"
        else
            jq --arg skill old-a '.skill_name = $skill' \
                "$workspace_dir/$extra" >"$historical_workspace/$extra"
        fi
    done
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a rename chain that resolves to an active terminal spec"
    rm -rf "$fixture/.agents/eval-workspaces/old-a"
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF

    jq '.evals += [{
        id: "second-case",
        prompt: "A second evaluation request.",
        expected_output: "The second result.",
        assertions: ["The second result is present."]
    }]' "$spec_dir/evals.json" >"$fixture/evals-expanded.json"
    mv "$fixture/evals-expanded.json" "$spec_dir/evals.json"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skill demo --iteration 2 >/dev/null ||
        fail "prepare task rejected an expanded evaluation specification"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a historical iteration after the spec gained a case"

    mv "$workspace_root/iteration-2/second-case" "$fixture/second-case-directory"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a current iteration with a missing case directory"
    fi
    mv "$fixture/second-case-directory" "$workspace_root/iteration-2/second-case"

    cp "$workspace_root/iteration-2/manifest.json" "$fixture/manifest-valid.json"
    jq '.case_ids = ["example-case"]' "$workspace_root/iteration-2/manifest.json" \
        >"$fixture/manifest-invalid.json"
    mv "$fixture/manifest-invalid.json" "$workspace_root/iteration-2/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted current-iteration case omission"
    fi
    mv "$fixture/manifest-valid.json" "$workspace_root/iteration-2/manifest.json"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skill demo --iteration 3 >/dev/null ||
        fail "prepare task rejected a restored current iteration"

    jq '.evals = [.evals[] | select(.id == "example-case")]' "$spec_dir/evals.json" \
        >"$fixture/evals-removed-case.json"
    mv "$fixture/evals-removed-case.json" "$spec_dir/evals.json"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skill demo --iteration 4 >/dev/null ||
        fail "prepare task rejected a specification with a removed case"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected historical cases removed from the current specification"

    mkdir "$workspace_root/iteration-5"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        if [[ "$extra" == manifest.json ]]; then
            jq --arg iteration 5 '.iteration = ($iteration | tonumber) | del(.state)' \
                "$workspace_root/iteration-4/$extra" >"$workspace_root/iteration-5/$extra"
        else
            jq --arg iteration 5 '.iteration = ($iteration | tonumber)' \
                "$workspace_root/iteration-4/$extra" >"$workspace_root/iteration-5/$extra"
        fi
    done
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an empty newest iteration without durable state"
    fi
    jq '.state = "materialized"' "$workspace_root/iteration-5/manifest.json" \
        >"$fixture/manifest-materialized.json"
    mv "$fixture/manifest-materialized.json" "$workspace_root/iteration-5/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a newest materialized iteration with a missing case directory"
    fi
    jq '.state = "preparation"' "$workspace_root/iteration-5/manifest.json" \
        >"$fixture/manifest-preparation.json"
    mv "$fixture/manifest-preparation.json" "$workspace_root/iteration-5/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a newest preparation iteration with a missing case directory"
    fi
    cp -R "$workspace_root/iteration-4/example-case" "$workspace_root/iteration-5/example-case"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a complete newest preparation iteration"

    cp "$workspace_root/iteration-5/benchmark.json" "$fixture/benchmark-preparation-valid.json"
    jq '.run_summary = {passed: 1}' "$workspace_root/iteration-5/benchmark.json" \
        >"$fixture/benchmark-preparation-invalid.json"
    mv "$fixture/benchmark-preparation-invalid.json" "$workspace_root/iteration-5/benchmark.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a fabricated preparation summary"
    fi
    mv "$fixture/benchmark-preparation-valid.json" "$workspace_root/iteration-5/benchmark.json"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a restored preparation summary"

    mv "$workspace_root/iteration-5/benchmark.json" "$fixture/benchmark-missing.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a preparation iteration with a missing summary report"
    fi
    mv "$fixture/benchmark-missing.json" "$workspace_root/iteration-5/benchmark.json"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a restored preparation iteration"
    rm -rf "$workspace_root/iteration-5"

    materialized_iteration="$workspace_root/iteration-6"
    materialized_case="$materialized_iteration/example-case"
    mkdir -p "$materialized_iteration"
    jq -n '{
        version: 1,
        skill_name: "demo",
        iteration: 6,
        case_ids: ["example-case"],
        state: "materialized"
    }' >"$materialized_iteration/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq -n '{
            skill_name: "demo",
            iteration: 6,
            provenance: {
                harness_identity: "test-harness",
                skill_identity: "demo",
                spec_id: "demo/evals/evals.json"
            },
            run: {
                duration_ms: 1,
                ended_at: "2026-01-01T00:00:20Z",
                evidence_files: ["example-case/with_skill/evidence/run.txt"],
                output_files: ["example-case/with_skill/outputs/run.txt"],
                redaction_status: "clean",
                result: "passed",
                run_id: "run-1",
                started_at: "2026-01-01T00:00:00Z",
                status: "completed"
            }
        }' >"$materialized_iteration/$extra"
    done
    for configuration in with_skill old_skill; do
        mkdir -p "$materialized_case/$configuration/outputs"
        mkdir -p "$materialized_case/$configuration/evidence"
        printf '%s\n' "materialized output" \
            >"$materialized_case/$configuration/outputs/run.txt"
        printf '%s\n' "materialized evidence" \
            >"$materialized_case/$configuration/evidence/run.txt"
        jq -n --arg configuration "$configuration" '{
            case_id: "example-case",
            configuration: $configuration,
            duration_ms: 1,
            ended_at: "2026-01-01T00:00:20Z",
            evidence_files: ["evidence/run.txt"],
            harness_identity: "test-harness",
            output_files: ["outputs/run.txt"],
            redaction_status: "clean",
            result: "passed",
            run_id: "run-1",
            skill_identity: "demo",
            spec_id: "demo/evals/evals.json",
            started_at: "2026-01-01T00:00:00Z",
            status: "completed",
            total_tokens: 1
        }' >"$materialized_case/$configuration/timing.json"
        jq -n --arg configuration "$configuration" '{
            assertion_results: [
                {
                    evidence: ["evidence/run.txt"],
                    id: "assertion-1",
                    status: "passed"
                }
            ],
            case_id: "example-case",
            configuration: $configuration,
            redaction_status: "clean",
            result: "passed",
            run_id: "run-1",
            status: "completed"
        }' >"$materialized_case/$configuration/grading.json"
    done
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a valid materialized fixture"

    selection_skill_dir="$fixture/.agents/skills/selection-demo"
    selection_spec_dir="$selection_skill_dir/evals"
    selection_workspace_root="$workspace_parent/selection-demo"
    selection_active="$selection_workspace_root/iteration-2"
    selection_retired="$selection_workspace_root/iteration-3"
    mkdir -p "$selection_spec_dir"
    printf '%s\n' '# Selection demo skill' >"$selection_skill_dir/SKILL.md"
    cat >"$selection_spec_dir/evals.json" <<'EOF'
{
  "skill_name": "selection-demo",
  "evals": [
    {
      "id": "expected-case",
      "prompt": "A selection regression case.",
      "expected_output": "The expected result.",
      "assertions": ["The expected result is present."]
    }
  ]
}
EOF
    mkdir -p "$selection_workspace_root"
    cp -R "$materialized_iteration" "$selection_active"
    mv "$selection_active/example-case" "$selection_active/mismatched-case"
    jq --arg skill selection-demo --argjson iteration 2 --arg case mismatched-case '
        .skill_name = $skill |
        .iteration = $iteration |
        .case_ids = [$case] |
        .state = "materialized" |
        del(.history_reason)
    ' "$selection_active/manifest.json" >"$fixture/selection-active-manifest.json"
    mv "$fixture/selection-active-manifest.json" "$selection_active/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq --arg skill selection-demo --argjson iteration 2 '
            .skill_name = $skill |
            .iteration = $iteration |
            .provenance.skill_identity = $skill |
            .provenance.spec_id = ($skill + "/evals/evals.json") |
            .run.output_files |= map(sub("^example-case/"; "mismatched-case/")) |
            .run.evidence_files |= map(sub("^example-case/"; "mismatched-case/"))
        ' "$selection_active/$extra" >"$fixture/selection-active-$extra"
        mv "$fixture/selection-active-$extra" "$selection_active/$extra"
    done
    for selection_configuration in with_skill old_skill; do
        jq --arg skill selection-demo --arg case mismatched-case --arg configuration "$selection_configuration" '
            .case_id = $case |
            .configuration = $configuration |
            .skill_identity = $skill |
            .spec_id = ($skill + "/evals/evals.json")
        ' "$selection_active/mismatched-case/$selection_configuration/timing.json" \
            >"$fixture/selection-active-timing.json"
        mv "$fixture/selection-active-timing.json" \
            "$selection_active/mismatched-case/$selection_configuration/timing.json"
        jq --arg case mismatched-case --arg configuration "$selection_configuration" '
            .case_id = $case |
            .configuration = $configuration
        ' "$selection_active/mismatched-case/$selection_configuration/grading.json" \
            >"$fixture/selection-active-grading.json"
        mv "$fixture/selection-active-grading.json" \
            "$selection_active/mismatched-case/$selection_configuration/grading.json"
    done

    cp -R "$selection_active" "$selection_retired"
    jq --argjson iteration 3 '
        .iteration = $iteration |
        .state = "historical" |
        .history_reason = "retired-materialized-incomplete"
    ' "$selection_retired/manifest.json" >"$fixture/selection-retired-manifest.json"
    mv "$fixture/selection-retired-manifest.json" "$selection_retired/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq --argjson iteration 3 '.iteration = $iteration' \
            "$selection_retired/$extra" >"$fixture/selection-retired-$extra"
        mv "$fixture/selection-retired-$extra" "$selection_retired/$extra"
    done
    for selection_configuration in with_skill old_skill; do
        rm -rf "$selection_retired/mismatched-case/$selection_configuration/outputs"
        rm -rf "$selection_retired/mismatched-case/$selection_configuration/evidence"
    done
    mv "$selection_active" "$fixture/selection-active-hidden"
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected the higher retired selection fixture"
    mv "$fixture/selection-active-hidden" "$selection_active"
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" 2>&1)" &&
        fail "validator let a retired incomplete iteration hide the current mismatch"
    print -r -- "$validation_output" |
        grep -qF "current evaluation manifest does not match the evaluation spec: .agents/eval-workspaces/selection-demo/iteration-2/manifest.json" ||
        fail "validator did not report the active iteration mismatch"
    rm -rf "$selection_skill_dir" "$selection_workspace_root"

    retired_iteration="$workspace_root/iteration-99"
    cp -R "$materialized_iteration" "$retired_iteration"
    jq '.iteration = 99 | .state = "historical" | .history_reason = "retired-materialized-incomplete"' \
        "$retired_iteration/manifest.json" >"$fixture/manifest-retired-with-cases.json"
    mv "$fixture/manifest-retired-with-cases.json" "$retired_iteration/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq '.iteration = 99' "$retired_iteration/$extra" \
            >"$fixture/$extra-retired-with-cases.json"
        mv "$fixture/$extra-retired-with-cases.json" "$retired_iteration/$extra"
    done
    for configuration in with_skill old_skill; do
        rm -rf "$retired_iteration/example-case/$configuration/outputs"
        rm -rf "$retired_iteration/example-case/$configuration/evidence"
    done
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected an incomplete retired historical iteration"

    for malformed in timing-identity timing-run timing-status timing-redaction \
        grading-identity grading-run grading-status grading-redaction grading-assertion grading-report; do
        cp "$retired_iteration/example-case/with_skill/timing.json" \
            "$fixture/timing-retired-valid.json"
        cp "$retired_iteration/example-case/with_skill/grading.json" \
            "$fixture/grading-retired-valid.json"
        case "$malformed" in
            timing-identity)
                jq '.case_id = "wrong-case"' \
                    "$retired_iteration/example-case/with_skill/timing.json" \
                    >"$fixture/timing-retired-invalid.json"
                mv "$fixture/timing-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/timing.json"
                ;;
            timing-run)
                jq '.run_id = "run-2"' \
                    "$retired_iteration/example-case/with_skill/timing.json" \
                    >"$fixture/timing-retired-invalid.json"
                mv "$fixture/timing-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/timing.json"
                ;;
            timing-status)
                jq '.status = "invalid"' \
                    "$retired_iteration/example-case/with_skill/timing.json" \
                    >"$fixture/timing-retired-invalid.json"
                mv "$fixture/timing-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/timing.json"
                ;;
            timing-redaction)
                jq '.redaction_status = "invalid"' \
                    "$retired_iteration/example-case/with_skill/timing.json" \
                    >"$fixture/timing-retired-invalid.json"
                mv "$fixture/timing-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/timing.json"
                ;;
            grading-identity)
                jq '.configuration = "wrong-config"' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
            grading-run)
                jq '.run_id = "run-2"' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
            grading-status)
                jq '.status = "invalid"' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
            grading-redaction)
                jq '.redaction_status = "invalid"' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
            grading-assertion)
                jq '.assertion_results = [{}]' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
            grading-report)
                jq '.unexpected = true' \
                    "$retired_iteration/example-case/with_skill/grading.json" \
                    >"$fixture/grading-retired-invalid.json"
                mv "$fixture/grading-retired-invalid.json" \
                    "$retired_iteration/example-case/with_skill/grading.json"
                ;;
        esac
        if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
            fail "validator accepted malformed $malformed metadata under the retired marker"
        fi
        mv "$fixture/timing-retired-valid.json" \
            "$retired_iteration/example-case/with_skill/timing.json"
        mv "$fixture/grading-retired-valid.json" \
            "$retired_iteration/example-case/with_skill/grading.json"
    done

    jq 'del(.history_reason)' "$retired_iteration/manifest.json" \
        >"$fixture/manifest-retired-missing-reason.json"
    mv "$fixture/manifest-retired-missing-reason.json" "$retired_iteration/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an incomplete historical iteration without its reason"
    fi
    jq '.history_reason = "arbitrary-history"' "$retired_iteration/manifest.json" \
        >"$fixture/manifest-retired-wrong-reason.json"
    mv "$fixture/manifest-retired-wrong-reason.json" "$retired_iteration/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an arbitrary historical reason"
    fi
    rm -rf "$retired_iteration"

    retired_iteration="$workspace_root/iteration-99"
    cp -R "$materialized_iteration" "$retired_iteration"
    jq '.iteration = 99 | .state = "historical" | .history_reason = "retired-materialized-incomplete"' \
        "$retired_iteration/manifest.json" >"$fixture/manifest-retired-complete.json"
    mv "$fixture/manifest-retired-complete.json" "$retired_iteration/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq '.iteration = 99' "$retired_iteration/$extra" \
            >"$fixture/$extra-retired-complete.json"
        mv "$fixture/$extra-retired-complete.json" "$retired_iteration/$extra"
    done
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" 2>&1)" &&
        fail "validator accepted complete materialized artifacts under the retired marker"
    print -r -- "$validation_output" |
        grep -qF "retired historical evaluation iteration is complete" ||
        fail "validator did not reject complete artifacts under the retired historical marker"
    rm -rf "$retired_iteration"

    cp "$materialized_case/old_skill/grading.json" "$fixture/grading-valid.json"
    jq '.run_id = "run-2"' "$materialized_case/old_skill/grading.json" \
        >"$fixture/grading-mismatched.json"
    mv "$fixture/grading-mismatched.json" "$materialized_case/old_skill/grading.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted mismatched timing and grading run IDs"
    fi
    mv "$fixture/grading-valid.json" "$materialized_case/old_skill/grading.json"

    historical_workspace="$fixture/.agents/eval-workspaces/legacy-demo/iteration-6"
    mkdir -p "$historical_workspace"
    cp "$materialized_iteration/manifest.json" "$historical_workspace/manifest.json"
    jq '.skill_name = "legacy-demo" | .state = "historical"' \
        "$historical_workspace/manifest.json" >"$fixture/historical-manifest.json"
    mv "$fixture/historical-manifest.json" "$historical_workspace/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq '.skill_name = "legacy-demo" |
            .provenance.skill_identity = "legacy-demo" |
            .provenance.spec_id = "legacy-demo/evals/evals.json"' \
            "$materialized_iteration/$extra" >"$historical_workspace/$extra"
    done
    for configuration in with_skill old_skill; do
        mkdir -p "$historical_workspace/example-case/$configuration"
        jq '.skill_identity = "legacy-demo" |
            .spec_id = "legacy-demo/evals/evals.json"' \
            "$materialized_case/$configuration/timing.json" \
            >"$historical_workspace/example-case/$configuration/timing.json"
        cp "$materialized_case/$configuration/grading.json" \
            "$historical_workspace/example-case/$configuration/grading.json"
        cp -R "$materialized_case/$configuration/outputs" \
            "$historical_workspace/example-case/$configuration/"
        mkdir -p "$historical_workspace/example-case/$configuration/evidence"
        printf '%s\n' "historical evidence" \
            >"$historical_workspace/example-case/$configuration/evidence/run.txt"
    done
    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected materialized artifacts in a historical iteration"
    rm "$historical_workspace/example-case/with_skill/evidence/run.txt"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted invalid evidence in a historical materialized iteration"
    fi
    rm -rf "$fixture/.agents/eval-workspaces/legacy-demo/iteration-6"

    jq '. + {legacy_preparation: {version: 1, skills: ["demo"]}}' "$migration_map" \
        >"$fixture/migration-map-legacy-preparation.json"
    mv "$fixture/migration-map-legacy-preparation.json" "$migration_map"
    mkdir -p "$workspace_root/iteration-7/example-case"
    jq '.iteration = 7 | del(.state)' "$materialized_iteration/manifest.json" \
        >"$fixture/manifest-legacy-preparation.json"
    mv "$fixture/manifest-legacy-preparation.json" \
        "$workspace_root/iteration-7/manifest.json"
    for extra in benchmark.json feedback.json grading-summary.json; do
        jq --argjson iteration 7 '.iteration = $iteration' \
            "$workspace_root/iteration-4/$extra" >"$workspace_root/iteration-7/$extra"
    done
    mkdir -p "$workspace_root/iteration-7/example-case/with_skill"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted materialized case artifacts as legacy preparation"
    fi
    rm -rf "$workspace_root/iteration-7"
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF

    case_path="$workspace_root/iteration-4/example-case"
    mv "$case_path" "$fixture/example-case-directory"
    printf '%s\n' 'not a directory' >"$case_path"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a non-directory manifest case path"
    fi
    rm "$case_path"
    mv "$fixture/example-case-directory" "$case_path"

    mkdir "$workspace_dir/unknown-case"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an unknown workspace case"
    fi
    rmdir "$workspace_dir/unknown-case"

    cp "$workspace_dir/manifest.json" "$fixture/manifest-valid.json"
    jq '.case_ids = ["Malformed-ID"]' "$workspace_dir/manifest.json" \
        >"$fixture/manifest-invalid.json"
    mv "$fixture/manifest-invalid.json" "$workspace_dir/manifest.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a malformed manifest case ID"
    fi
    mv "$fixture/manifest-valid.json" "$workspace_dir/manifest.json"

    cp "$case_path/with_skill/timing.json" "$fixture/timing-valid.json"
    rm "$case_path/with_skill/timing.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a missing case report"
    fi
    mv "$fixture/timing-valid.json" "$case_path/with_skill/timing.json"

    global_skill_dir="$fixture/alternate/.agents/skills/global"
    global_workspace_dir="$fixture/.agents/eval-workspaces/global/iteration-1"
    mkdir -p "$global_skill_dir"
    printf '%s\n' '# Global skill' >"$global_skill_dir/SKILL.md"
    mise run ai:skills:evals:init --base-path "$fixture" --skills-path alternate/.agents/skills \
        --skill global >/dev/null ||
        fail "init task rejected the alternate skill root"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skills-path alternate/.agents/skills \
        --skill global --iteration 1 >/dev/null ||
        fail "prepare task rejected the alternate skill root"
    [[ -f "$global_workspace_dir/manifest.json" ]] ||
        fail "alternate skill workspace was not created"
    mise run ai:skills:evals:validate --base-path "$fixture" --skills-path .agents/skills >/dev/null ||
        fail "validator rejected a workspace owned by the alternate skill root"
    mise run ai:skills:evals:validate --base-path "$fixture" --skills-path alternate/.agents/skills >/dev/null ||
        fail "validator rejected the alternate skill root workspace"

    cp "$global_skill_dir/evals/evals.json" "$fixture/global-evals.valid.json"
    jq '.evals = []' "$global_skill_dir/evals/evals.json" \
        >"$fixture/global-evals.invalid.json"
    mv "$fixture/global-evals.invalid.json" "$global_skill_dir/evals/evals.json"
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" \
        --skills-path .agents/skills 2>&1)" &&
        fail "validator accepted a malformed alternate-root evaluation spec"
    print -r -- "$validation_output" |
        grep -qF "invalid evaluation spec: alternate/.agents/skills/global/evals/evals.json" ||
        fail "validator did not report the malformed alternate-root evaluation spec"
    mv "$fixture/global-evals.valid.json" "$global_skill_dir/evals/evals.json"

    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    },
    {
      "from": "legacy-global",
      "to": "global"
    }
  ]
}
EOF
    renamed_workspace="$fixture/.agents/eval-workspaces/legacy-global/iteration-1"
    mkdir -p "$renamed_workspace"
    for extra in manifest.json benchmark.json feedback.json grading-summary.json; do
        if [[ "$extra" == manifest.json ]]; then
            jq --arg skill legacy-global '.skill_name = $skill | del(.state)' \
                "$global_workspace_dir/$extra" >"$renamed_workspace/$extra"
        else
            jq --arg skill legacy-global '.skill_name = $skill' \
                "$global_workspace_dir/$extra" >"$renamed_workspace/$extra"
        fi
    done
    mise run ai:skills:evals:validate --base-path "$fixture" --skills-path .agents/skills >/dev/null ||
        fail "validator rejected a renamed workspace resolved to an alternate-root spec"
    rm -rf "$global_workspace_dir"

    cp "$global_skill_dir/evals/evals.json" "$fixture/global-evals.valid.json"
    jq '.evals = []' "$global_skill_dir/evals/evals.json" \
        >"$fixture/global-evals.invalid.json"
    mv "$fixture/global-evals.invalid.json" "$global_skill_dir/evals/evals.json"
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" \
        --skills-path .agents/skills 2>&1)" &&
        fail "validator silently skipped a renamed workspace with a malformed alternate-root spec"
    print -r -- "$validation_output" |
        grep -qF "invalid evaluation spec: alternate/.agents/skills/global/evals/evals.json" ||
        fail "validator did not report the renamed workspace's malformed alternate-root spec"
    mv "$fixture/global-evals.valid.json" "$global_skill_dir/evals/evals.json"
    rm -rf "$renamed_workspace"
    rm -rf "${renamed_workspace:h}"
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF

    collision_primary_dir="$fixture/.agents/skills/collision"
    collision_alternate_dir="$fixture/alternate/.agents/skills/collision"
    mkdir -p "$collision_primary_dir/evals" "$collision_alternate_dir/evals"
    printf '%s\n' '# Primary collision skill' >"$collision_primary_dir/SKILL.md"
    printf '%s\n' '# Alternate collision skill' >"$collision_alternate_dir/SKILL.md"
    jq -n '{
        skill_name: "collision",
        evals: [{
            id: "primary-case",
            prompt: "Use the primary collision specification.",
            expected_output: "Primary collision result.",
            assertions: ["The primary collision result is present."]
        }]
    }' >"$collision_primary_dir/evals/evals.json"
    jq -n '{
        skill_name: "collision",
        evals: [{
            id: "alternate-case",
            prompt: "Use the alternate collision specification.",
            expected_output: "Alternate collision result.",
            assertions: ["The alternate collision result is present."]
        }]
    }' >"$collision_alternate_dir/evals/evals.json"
    validation_output="$(mise run ai:skills:evals:validate --base-path "$fixture" \
        --skills-path .agents/skills 2>&1)" &&
        fail "validator silently selected one of two same-named skill roots"
    print -r -- "$validation_output" |
        grep -qF "duplicate skill name across skill roots: collision" ||
        fail "validator did not report the duplicate skill name"
    print -r -- "$validation_output" |
        grep -qF ".agents/skills/collision" ||
        fail "duplicate skill error did not identify the primary root"
    print -r -- "$validation_output" |
        grep -qF "alternate/.agents/skills/collision" ||
        fail "duplicate skill error did not identify the alternate root"

    rm -rf "$collision_alternate_dir"
    mise run ai:skills:evals:validate --base-path "$fixture" \
        --skills-path .agents/skills >/dev/null ||
        fail "validator rejected a skill found only in the primary root"

    mkdir -p "$collision_alternate_dir/evals"
    printf '%s\n' '# Alternate collision skill' >"$collision_alternate_dir/SKILL.md"
    cp "$fixture/alternate/.agents/skills/global/evals/evals.json" \
        "$collision_alternate_dir/evals/evals.json"
    jq --arg skill collision '.skill_name = $skill' \
        "$collision_alternate_dir/evals/evals.json" >"$fixture/collision-alternate-evals.json"
    mv "$fixture/collision-alternate-evals.json" "$collision_alternate_dir/evals/evals.json"
    rm -rf "$collision_primary_dir"
    mise run ai:skills:evals:validate --base-path "$fixture" \
        --skills-path .agents/skills >/dev/null ||
        fail "validator rejected a skill found only in the alternate root"
    rm -rf "$collision_alternate_dir"

    mise run ai:skills:validate-conflicts --base-path "$fixture" >/dev/null ||
        fail "skill conflict validator rejected a clean fixture"
    mise run mise:tasks:validate-conflicts --base-path "$fixture" >/dev/null ||
        fail "conflict validator rejected a clean fixture"
    git check-ignore -q --no-index \
        ".agents/eval-workspaces/demo/iteration-1/valid-case/with_skill/outputs/run-1.txt" ||
        fail "repository-local evaluation output is not ignored"
    git check-ignore -q --no-index \
        "home/.agents/skills/demo/evals/iteration-1/outputs/run-1.txt" ||
        fail "skill-local evaluation output is not ignored"
    git check-ignore -q --no-index \
        ".agents/eval-workspaces/demo/iteration-1/valid-case/with_skill/timing.json" ||
        fail "evaluation timing metadata is not ignored"
    git check-ignore -q --no-index \
        ".agents/eval-workspaces/demo/iteration-1/valid-case/with_skill/grading.json" ||
        fail "evaluation grading metadata is not ignored"

    cp "$spec_dir/evals.json" "$fixture/evals.json.valid"
    sed 's/"evals"/"cases"/' "$spec_dir/evals.json" >"$spec_dir/evals.invalid.json"
    mv "$spec_dir/evals.invalid.json" "$spec_dir/evals.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted legacy evaluation spec keys"
    fi
    mv "$fixture/evals.json.valid" "$spec_dir/evals.json"

    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF
    mkdir -p "$fixture/.agents/skills/legacy-demo"
    printf '%s\n' '# Legacy demo skill' >"$fixture/.agents/skills/legacy-demo/SKILL.md"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an active old skill name without an evaluation spec"
    fi
    mise run ai:skills:evals:init --base-path "$fixture" --skill legacy-demo >/dev/null ||
        fail "init task rejected an active historical skill name"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted an active old skill name"
    fi
    rm -rf "$fixture/.agents/skills/legacy-demo"
    cat >"$migration_map" <<'EOF'
{
  "version": 1,
  "renames": [
    {
      "from": "legacy-demo",
      "to": "demo"
    }
  ]
}
EOF

    ln -s "$spec_dir/evals.json" "$workspace_dir/linked.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a workspace symlink"
    fi
    rm "$workspace_dir/linked.json"

    printf '%s\n' '{}' >"$workspace_dir/example-case/with_skill/outputs/timing-1.json"
    if mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null 2>&1; then
        fail "validator accepted a legacy timing artifact"
    fi
    rm "$workspace_dir/example-case/with_skill/outputs/timing-1.json"

    ln -s "$HOME/.agents/skills/agent-instructions-evaluation" \
        "$fixture/.agents/skills/agent-instructions-evaluation"
    if mise run ai:skills:validate-conflicts --base-path "$fixture" >/dev/null 2>&1; then
        fail "conflict validator accepted a duplicate skill name"
    fi
    rm -rf "$fixture/.agents/skills/agent-instructions-evaluation"

    cat >"$fixture/mise.toml" <<'EOF'
[tasks."mise:tasks:validate-conflicts"]
run = "true"
EOF
    if mise run mise:tasks:validate-conflicts --base-path "$fixture" >/dev/null 2>&1; then
        fail "conflict validator accepted a duplicate task name"
    fi

    print "Skill evaluation validation passed."
}

main "$@"
