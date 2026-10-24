#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing coreutils package bootstrap configuration..."
assert_module_package coreutils brew:coreutils
local __config="home/.config/mise/conf.d/coreutils.toml"
local __source="home/.config/coreutils/zshrc.zsh"
[[ -f "$__source" ]] || fail "missing coreutils Zsh source"
zsh -n "$__source" || fail "coreutils Zsh source has syntax errors"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/coreutils"' "$__config" ||
    fail "coreutils Zsh edit is missing"
echo "coreutils package bootstrap configuration passed."
