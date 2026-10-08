#!/usr/bin/env zsh
# Test the mise tools configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise tools configuration..."

local __config=".config/mise/conf.d/tools.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF "[tools]" "$__config" || fail "tools section is missing"

for __tool in rust node python ruby bun go uv opencode; do
    grep -qE "^${__tool}[[:space:]]*=" "$__config" || fail "tool $__tool is missing"
done

echo "Mise tools configuration passed."
