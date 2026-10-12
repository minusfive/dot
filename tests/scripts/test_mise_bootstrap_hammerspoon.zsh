#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Hammerspoon bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.hammerspoon.toml"
local __source="home/.config/hammerspoon"
local __target="$HOME/.config/hammerspoon"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/hammerspoon" = { source = "~/dev/personal/dot/home/.config/hammerspoon", mode = "symlink-each" }' "$__config" ||
    fail "Hammerspoon symlink-each declaration is missing"
[[ ! -e "$__source/.luarc.json" ]] || fail "repository-only .luarc.json entered the mise source"
[[ ! -e "$__target/.luarc.json" ]] || fail "repository-only .luarc.json leaked into the target"
local __expected_count="$(git ls-files -- .config/hammerspoon | grep -v '^.config/hammerspoon/.luarc.json$' | wc -l | tr -d ' ')"
local __source_count="$(find "$__source" -type f | wc -l | tr -d ' ')"
local __link_count="$(find "$__target" -type l | wc -l | tr -d ' ')"
[[ "$__source_count" == "$__expected_count" ]] || fail "Hammerspoon source manifest mismatch"
[[ "$__link_count" == "$__expected_count" ]] || fail "Hammerspoon target link count mismatch"
find "$__target" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} + ||
    fail "Hammerspoon deployed link is absolute"
if command -v luac >/dev/null 2>&1; then
    find "$__source" -type f -name '*.lua' -exec luac -p {} +
fi

echo "Hammerspoon bootstrap configuration passed."
