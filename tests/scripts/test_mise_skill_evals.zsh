#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    local fixture skill_dir spec_dir workspace_dir global_skill_dir global_workspace_dir

    fixture="$(test_fixture_dir skill-evals)" || fail "could not create fixture directory"
    trap "rm -rf -- '$fixture'" EXIT
    skill_dir="$fixture/.agents/skills/demo"
    spec_dir="$skill_dir/evals"
    workspace_dir="$fixture/.agents/eval-workspaces/demo/iteration-1"
    mkdir -p "$skill_dir"
    git -C "$fixture" init -q
    printf '%s\n' '# Demo skill' >"$skill_dir/SKILL.md"

    mise run ai:skills:evals:init --base-path "$fixture" --skill demo >/dev/null ||
        fail "init task rejected a valid skill"
    mise run ai:skills:evals:prepare --base-path "$fixture" --skill demo --iteration 1 >/dev/null ||
        fail "prepare task rejected a valid evaluation specification"
    [[ -f "$workspace_dir/manifest.json" ]] || fail "prepare task did not create a manifest"
    [[ -f "$workspace_dir/example-case/with_skill/timing.json" ]] ||
        fail "prepare task did not create with_skill timing metadata"
    [[ -f "$workspace_dir/example-case/old_skill/grading.json" ]] ||
        fail "prepare task did not create old_skill grading metadata"

    mise run ai:skills:evals:validate --base-path "$fixture" >/dev/null ||
        fail "validator rejected a valid fixture"

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
