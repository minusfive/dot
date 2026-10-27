#!/usr/bin/env zsh
# Test the shared package maintenance hook.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package maintenance configuration..."

local __config="home/.config/mise/conf.d/packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"mise/config/mise/conf.d/packages.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "mise control-plane module does not deploy packages.toml"
grep -qF "[bootstrap.hooks]" "$__config" || fail "package bootstrap hooks are missing"
grep -qF '"mise bootstrap packages upgrade --yes"' "$__config" ||
    fail "package upgrade hook is missing"
grep -qF '"mise bootstrap packages prune --yes"' "$__config" ||
    fail "package prune hook is missing"

local __packages_profile_config
for __profile in work personal; do
    __packages_profile_config="$(
        env MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
            mise -C "$__test_mise_repository" config ls --no-truncate
    )"
    print -r -- "$__packages_profile_config" | grep -qF "packages.toml" ||
        fail "packages must be selected by the $__profile profile"
done

echo "Shared package maintenance configuration passed."
