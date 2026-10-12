#!/usr/bin/env zsh
# Test the brew bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.brew.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ ! -e "home/.config/mise/conf.d/module.packages.toml" ]] ||
    fail "legacy package module must be retired"
if [[ -e "home/.config/mise/conf.d/bootstrap-packages.toml" ]]; then
    fail "legacy shared package declaration must be retired"
fi
grep -qF '"~/.config/mise/conf.d/module.brew.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.brew.toml"
grep -qF "[bootstrap.brew]" "$__config" || fail "Homebrew bootstrap section is missing"
grep -qF "adopt = true" "$__config" || fail "Homebrew adoption is missing"
if grep -qF "[bootstrap.packages]" "$__config"; then
    fail "shared package declarations should be moved to package modules"
fi

local __shared_profile_count="$(grep -o '"brew"' home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
[[ "$__shared_profile_count" -eq 2 ]] || fail "shared package module must be selected by both profiles"

if grep -qF "[bootstrap.brew.taps]" "$__config"; then
    fail "Homebrew taps should not be declared here"
fi
if grep -qF '"brew:mise" = "latest"' "$__config"; then
    fail "mise should not be installed as a bootstrap package"
fi

echo "Shared package bootstrap configuration passed."
