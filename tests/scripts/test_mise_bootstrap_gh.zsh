#!/usr/bin/env zsh
# Test the GitHub bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GitHub bootstrap configuration..."

local __config=".config/mise/conf.d/bootstrap-gh.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/dev/profile.mise.toml" ]] || fail "missing profile source"
[[ -f "home/.config/gh/personal/hosts.yml" ]] || fail "missing GitHub hosts source"
if grep -qF "oauth_token:" "home/.config/gh/personal/hosts.yml"; then
    fail "GitHub hosts source must not contain an OAuth token"
fi

grep -qF 'source = "../../../home/dev/profile.mise.toml"' "$__config" || fail "profile source is missing"
grep -qF '[bootstrap.directories."~/.config/gh/personal"]' "$__config" || fail "GitHub directory resource is missing"
grep -qF '[bootstrap.files."~/.config/gh/personal/hosts.yml"]' "$__config" || fail "GitHub hosts resource is missing"
grep -qF 'source = "../../../home/.config/gh/personal/hosts.yml"' "$__config" || fail "GitHub hosts source is missing"
grep -qF 'mode = "0644"' "$__config" || fail "GitHub hosts mode is missing"

echo "GitHub bootstrap configuration passed."
