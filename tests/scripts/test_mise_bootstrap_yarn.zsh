#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Yarn bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.yarn.toml"
local __source="home/.config/yarn/zshrc.zsh"
[[ -f "$__config" && -f "$__source" ]] || fail "Yarn source or declaration is missing"
zsh -n "$__source" || fail "Yarn Zsh source has syntax errors"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/yarn"' "$__config" ||
    fail "Yarn Zsh edit is missing"
grep -qF '"~/.config/mise/conf.d/module.yarn.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.yarn.toml"
for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.yarn.toml" ||
        fail "Yarn module must be selected by the $__profile profile"
done

echo "Yarn bootstrap configuration passed."
