#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    local fixture skill_dir spec_dir workspace_parent workspace_dir workspace_root case_path
    local materialized_iteration materialized_case configuration
    local migration_map historical_workspace global_skill_dir global_workspace_dir
    local validation_output

    fixture="$(test_fixture_dir skill-evals)" || fail "could not create fixture directory"
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
    mise run ai:skills:evals:validate --base-path home >/dev/null ||
        fail "validator did not resolve its migration map from the task source"

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
