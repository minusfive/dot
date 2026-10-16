#!/usr/bin/env zsh
# Test the shared package maintenance hook.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package maintenance configuration..."

local __config="home/.config/mise/conf.d/module.packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/mise/conf.d/module.packages.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.packages.toml"
grep -qF "[bootstrap.hooks]" "$__config" || fail "package bootstrap hooks are missing"
grep -qF '"mise bootstrap packages upgrade --yes"' "$__config" ||
    fail "package upgrade hook is missing"
grep -qF '"mise bootstrap packages prune --yes"' "$__config" ||
    fail "package prune hook is missing"

local __profile_count="$(grep -o '"packages"' home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
[[ "$__profile_count" -eq 2 ]] || fail "packages must be selected by both profiles"

echo "Shared package maintenance configuration passed."
