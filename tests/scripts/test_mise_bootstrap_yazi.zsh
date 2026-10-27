#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Yazi bootstrap configuration..."

local __config="home/.config/mise/conf.d/yazi.toml"
assert_module_package yazi brew:yazi
local __source="home/.config/yazi"
local __target="$HOME/.config/yazi"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"yazi/config/yazi" = { source = "~/dev/personal/dot/home/.config/yazi", mode = "symlink-each", exclude = ["zshrc.zsh"], variants = [{ default = true, target = "{{ xdg_config_home }}/yazi" }] }' "$__config" ||
    fail "Yazi symlink-each declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/yazi"' "$__config" ||
    fail "Yazi zshrc edit is missing"
[[ -d "$__target" && ! -L "$__target" ]] || fail "Yazi target must be a physical directory"
local __source_count="$(find "$__source" -type f | wc -l | tr -d ' ')"
[[ "$__source_count" == "15" ]] || fail "expected 15 tracked Yazi source files, found $__source_count"
local __target_count="$(find "$__target" -type l | wc -l | tr -d ' ')"
[[ "$__target_count" == "14" ]] || fail "expected 14 Yazi links, found $__target_count"
find "$__target" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} + ||
    fail "Yazi deployed link is absolute"
grep -qF '3d0c7c6' "$__source/package.toml" || fail "Yazi no-status revision pin changed"
grep -qF '513a23ac28e1eaa626f3a1bb6c8130d' "$__source/package.toml" || fail "Yazi no-status hash changed"
grep -qF 'c023460' "$__source/package.toml" || fail "Yazi flavor revision pin changed"
grep -qF '2ac87e1b3a61f5887472899e86535d29' "$__source/package.toml" || fail "Yazi flavor hash changed"
yazi --version >/dev/null || fail "Yazi is unavailable"
ya --version >/dev/null || fail "ya is unavailable"

echo "Yazi bootstrap configuration passed."
