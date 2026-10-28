#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing dockutil package bootstrap configuration..."
local __config="home/.config/mise/conf.d/dockutil.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"brew:dockutil" = "latest"' "$__config" ||
    fail "dockutil package declaration is missing"
grep -qF 'post-user = "mise run macos:dock:folders"' "$__config" ||
    fail "dockutil macOS hook is missing"
echo "dockutil package bootstrap configuration passed."
