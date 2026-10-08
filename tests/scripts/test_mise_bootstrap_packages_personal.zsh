#!/usr/bin/env zsh
# Test the personal package bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing personal package bootstrap configuration..."

local __config=".config/mise/conf.d/bootstrap-packages.personal.toml"
local __shared=".config/mise/conf.d/bootstrap-packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"

for __cask in discord softraid whatsapp; do
    grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__config" || fail "personal cask $__cask is missing"
done

for __cask in discord softraid whatsapp; do
    if grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__shared"; then
        fail "personal cask $__cask should not be in shared config"
    fi
done

echo "Personal package bootstrap configuration passed."
