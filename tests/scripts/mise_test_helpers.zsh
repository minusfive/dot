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

cd "$__root_dir"
