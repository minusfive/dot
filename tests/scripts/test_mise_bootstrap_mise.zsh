#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise control-plane module..."

local __config="home/.config/mise/conf.d/module.mise.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/mise/conf.d/module.mise.toml"' "$__config" ||
    fail "mise control-plane module does not manage itself"
grep -qF '"~/.config/mise/tasks/global-install-packages-all.sh"' "$__config" ||
    fail "aggregate package task is missing"
grep -qF '"~/.config/mise/tasks/mise/cleanup.zsh"' "$__config" ||
    fail "stale-link cleanup task is missing"
grep -qF '"~/.config/mise/tasks/mise/cleanup/inventory.zsh"' "$__config" ||
    fail "cleanup inventory task is missing"
grep -qF '"mise upgrade --prune"' "$__config" ||
    fail "tool upgrade hook is missing"
grep -qF '"mise reshim -f"' "$__config" ||
    fail "tool reshim hook is missing"
[[ ! -e "home/.config/mise/conf.d/module.tools.toml" ]] ||
    fail "combined tools module remains"
[[ ! -e "home/.config/mise/conf.d/module.uv.toml" ]] ||
    fail "standalone uv module remains"
if grep -qF '[[tools.opencode]]' home/.config/mise/mise.lock; then
    fail "OpenCode tool lock entry must be removed"
fi
if grep -qF '[[tools."npm:mcp-hub"]]' home/.config/mise/mise.lock; then
    fail "mcp-hub tool lock entry must be removed"
fi

echo "mise control-plane module passed."
