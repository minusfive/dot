#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

typeset -r __test_dir="$(realpath "$(dirname "$0")")"
typeset -r __root_dir="$(dirname "$(dirname "$__test_dir")")"

function main {
    local __fixture_root
    __fixture_root="$(test_fixture_dir agentic-projects)" || exit 1
    trap "rm -rf -- ${(q)__fixture_root}" EXIT
    local __script="$__root_dir/home/.agents/skills/agentic-projects/scripts/manage-agentic-project.sh"

    mkdir -p "$__fixture_root/repo"

    "$__script" \
        --repo-root "$__fixture_root/repo" \
        --project hidden-project \
        --prompt "private plan"
    test -f "$__fixture_root/repo/.agents/projects.local/hidden-project/PROMPT.md"
    test ! -e "$__fixture_root/repo/.agents/projects.local/hidden-project/.gitignore"

    "$__script" \
        --repo-root "$__fixture_root/repo" \
        --project hidden-project \
        --promoted
    test ! -e "$__fixture_root/repo/.agents/projects.local/hidden-project"
    test -f "$__fixture_root/repo/.agents/projects/hidden-project/PROMPT.md"
    test ! -e "$__fixture_root/repo/.agents/projects/hidden-project/.gitignore"

    "$__script" \
        --repo-root "$__fixture_root/repo" \
        --project promoted-project \
        --prompt "checked in plan" \
        --promoted
    test -f "$__fixture_root/repo/.agents/projects/promoted-project/PROMPT.md"

    print "Agentic project placement checks passed."
}

main "$@"
