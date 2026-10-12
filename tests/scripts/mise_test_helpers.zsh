#!/usr/bin/env zsh

set -euo pipefail

typeset -g __test_dir="$(realpath "$(dirname "$0")")"
typeset -g __root_dir="$(dirname "$(dirname "$__test_dir")")"

fail() {
    echo "FAIL: $1"
    exit 1
}

line_of() {
    local __needle="$1"
    local __line
    __line="$(grep -nF "$__needle" "$__root_dir/scripts/mise.zsh" | head -n1 | cut -d: -f1 || true)"
    print -r -- "$__line"
}

assert_module_package() {
    local __module="$1"
    local __package="$2"
    local __config="home/.config/mise/conf.d/module.$__module.toml"
    local __profile_count
    [[ -f "$__config" ]] || fail "missing $__config"
    grep -q "\"$__package\" = \"latest\"" "$__config" ||
        fail "$__package is missing from $__config"
    __profile_count="$(grep -o "\"$__module\"" home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
    [[ "$__profile_count" -eq 2 ]] || fail "$__module must be selected by both profiles"
}

cd "$__root_dir"
