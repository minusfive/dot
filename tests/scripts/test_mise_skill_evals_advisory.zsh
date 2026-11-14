#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    local fixture task_root mise_config output
    local workspace_root demo_skill stale_skill alternate_skill

    fixture="$(test_fixture_dir skill-evals-advisory)" || fail "could not create fixture directory"
    trap "rm -rf -- '$fixture'" EXIT
    task_root="$__root_dir"
    mise_config="$__test_mise_config_dir"
    workspace_root="$fixture/.agents/eval-workspaces"
    demo_skill="$fixture/.agents/skills/demo"
    stale_skill="$fixture/.agents/skills/stale"
    alternate_skill="$fixture/alternate/.agents/skills/demo"
    mkdir -p "$demo_skill" "$stale_skill"
    printf '%s\n' '# Demo skill' >"$demo_skill/SKILL.md"
    printf '%s\n' '# Stale skill' >"$stale_skill/SKILL.md"
    git -C "$fixture" init -q

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:init \
        --base-path "$fixture" --skill demo >/dev/null ||
        fail "could not initialize demo evaluation"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "could not prepare demo iteration 1"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill demo --iteration 2 >/dev/null ||
        fail "could not prepare demo iteration 2"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:init \
        --base-path "$fixture" --skill stale >/dev/null ||
        fail "could not initialize stale evaluation"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:prepare \
        --base-path "$fixture" --skill stale --iteration 1 >/dev/null ||
        fail "could not prepare stale iteration"

    printf '%s\n' '{}' >"$workspace_root/stale/iteration-1/example-case/with_skill/timing.json"
    output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
            --base-path "$fixture" --skill demo 2>&1
    )" || fail "filtered validation rejected an unrelated stale workspace"
    print -r -- "$output" | grep -qF '"level":"warning"' ||
        fail "filtered validation warning was not structured"
    print -r -- "$output" | grep -qF '"code":"workspace-out-of-scope"' ||
        fail "filtered validation did not emit a structured warning"

    jq '.state = "materialized"' \
        "$workspace_root/demo/iteration-1/manifest.json" >"$fixture/demo-manifest.json"
    mv "$fixture/demo-manifest.json" "$workspace_root/demo/iteration-1/manifest.json"
    printf '%s\n' '{}' >"$workspace_root/demo/iteration-1/example-case/with_skill/timing.json"
    output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
            --base-path "$fixture" --skill demo --iteration 1 2>&1
    )" && fail "current target failure was accepted"
    print -r -- "$output" | grep -qF "invalid materialized timing report" ||
        fail "current target failure was not reported"

    jq '.state = "materialized"' \
        "$workspace_root/demo/iteration-1/manifest.json" >"$fixture/demo-manifest.json"
    mv "$fixture/demo-manifest.json" "$workspace_root/demo/iteration-1/manifest.json"
    printf '%s\n' '{}' >"$workspace_root/demo/iteration-1/example-case/with_skill/timing.json"
    output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
            --base-path "$fixture" 2>&1
    )" || fail "ordinary validation rejected an incomplete historical workspace"
    print -r -- "$output" | grep -qF '"code":"workspace-incomplete"' ||
        fail "ordinary validation did not warn about incomplete history"

    output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
            --base-path "$fixture" --strict 2>&1
    )" && fail "strict validation accepted incomplete history"
    print -r -- "$output" | grep -qF "invalid materialized timing report" ||
        fail "strict validation did not report incomplete history"

    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
        --base-path "$fixture" --skills-path .agents/skills/./ --skill demo --iteration 2 >/dev/null 2>&1 ||
        fail "canonicalized identical skill root was rejected"

    mkdir -p "$alternate_skill"
    printf '%s\n' '# Alternate demo skill' >"$alternate_skill/SKILL.md"
    MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:init \
        --base-path "$fixture" --skills-path alternate/.agents/skills --skill demo >/dev/null ||
        fail "could not initialize the conflicting alternate skill"
    output="$(
        MISE_CONFIG_DIR="$mise_config" mise -C "$task_root" run ai:skills:evals:validate \
            --base-path "$fixture" --skill stale 2>&1
    )" && fail "conflicting distinct skill roots were accepted"
    print -r -- "$output" | grep -qF "duplicate skill name across skill roots: demo" ||
        fail "conflicting distinct skill roots were not rejected"

    print "Advisory skill evaluation validation passed."
}

main "$@"
