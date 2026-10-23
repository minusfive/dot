#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing findutils package bootstrap configuration..."
assert_module_package findutils brew:findutils
local __config="home/.config/mise/conf.d/module-findutils.toml"
local __source="home/.config/findutils/zshrc.zsh"
[[ -f "$__source" ]] || fail "missing findutils Zsh source"
zsh -n "$__source" || fail "findutils Zsh source has syntax errors"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/findutils"' "$__config" ||
    fail "findutils Zsh edit is missing"
echo "findutils package bootstrap configuration passed."
