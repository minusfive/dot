#!/usr/bin/env zsh
# Test the personal package bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing personal package bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.personal-packages.toml"
local __shared="home/.config/mise/conf.d/module.packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ ! -e "home/.config/mise/conf.d/bootstrap-packages.personal.toml" ]] ||
    fail "legacy personal package declaration must be retired"
grep -qF '"~/.config/mise/conf.d/module.personal-packages.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.personal-packages.toml"
grep -qF '"personal-packages"' home/.config/mise/miserc.toml ||
    fail "personal package module is not selected"
if sed -n '/{% else %}/,$p' home/.config/mise/miserc.toml | grep -qF 'personal-packages'; then
    fail "personal package module must not be selected by the work profile"
fi

for __cask in discord softraid whatsapp; do
    grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__config" || fail "personal cask $__cask is missing"
done

for __cask in discord softraid whatsapp; do
    if grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__shared"; then
        fail "personal cask $__cask should not be in shared config"
    fi
done

echo "Personal package bootstrap configuration passed."
