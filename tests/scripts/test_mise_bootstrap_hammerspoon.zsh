#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Hammerspoon bootstrap configuration..."

local __config="home/.config/mise/conf.d/hammerspoon.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"brew-cask:hammerspoon" = "latest"' "$__config" ||
    fail "Hammerspoon package declaration is missing"
grep -qF '"~/.config/hammerspoon" = {' "$__config" ||
    fail "Hammerspoon symlink declaration is missing"
grep -qF 'MJConfigFile' "$__config" ||
    fail "Hammerspoon macOS hook is missing"
grep -qF '"~/.config/mise/conf.d/hammerspoon.toml" = {' home/.config/mise/conf.d/mise.toml ||
    fail "Hammerspoon module is not deployed"
grep -qF "'hammerspoon'" home/.config/mise/miserc.toml ||
    fail "Hammerspoon is not selected by the shared profile modules"
local __source="home/.config/hammerspoon"
local __target="$HOME/.config/hammerspoon"
[[ -f "$__source/.luarc.json" ]] || fail "Hammerspoon local-development source is missing"
[[ ! -e ".config/hammerspoon/.luarc.json" ]] ||
    fail "Hammerspoon local-development source remains under the legacy boundary"
[[ ! -e "$__target/.luarc.json" ]] || fail "repository-only .luarc.json leaked into the target"
local __expected_count="$(git ls-files -- home/.config/hammerspoon | grep -v '^home/.config/hammerspoon/.luarc.json$' | wc -l | tr -d ' ')"
local __source_count="$(find "$__source" -type f ! -name '.luarc.json' | wc -l | tr -d ' ')"
local __link_count="$(find "$__target" -type l | wc -l | tr -d ' ')"
[[ "$__source_count" == "$__expected_count" ]] || fail "Hammerspoon source manifest mismatch"
[[ "$__link_count" == "$__expected_count" ]] || fail "Hammerspoon target link count mismatch"
find "$__target" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} + ||
    fail "Hammerspoon deployed link is absolute"
if command -v luac >/dev/null 2>&1; then
    find "$__source" -type f -name '*.lua' -exec luac -p {} +
fi

echo "Hammerspoon bootstrap configuration passed."
