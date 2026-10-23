#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing curl package bootstrap configuration..."
assert_module_package curl brew:curl
local __config="home/.config/mise/conf.d/module-curl.toml"
local __source="home/.config/curl/zshrc.zsh"
[[ -f "$__source" ]] || fail "missing curl Zsh source"
zsh -n "$__source" || fail "curl Zsh source has syntax errors"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/curl"' "$__config" ||
    fail "curl Zsh edit is missing"
echo "curl package bootstrap configuration passed."
