#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Ghostty bootstrap configuration..."

local __config="home/.config/mise/conf.d/module-ghostty.toml"
assert_module_package ghostty brew-cask:ghostty
local __source="home/.config/ghostty"
local __target="$HOME/.config/ghostty"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/ghostty" = { source = "~/dev/personal/dot/home/.config/ghostty", mode = "symlink-each" }' "$__config" ||
    fail "Ghostty symlink-each declaration is missing"
for __path in \
    config \
    shaders/cursor_smear.glsl \
    shaders/cursor_smear_fade.glsl \
    'shaders/cursor_synesthaxia(tweened).glsl'; do
    [[ -f "$__source/$__path" ]] || fail "missing Ghostty source: $__path"
    [[ -L "$__target/$__path" ]] || fail "Ghostty target is not a symlink: $__path"
    case "$(readlink "$__target/$__path")" in
        /*) fail "Ghostty target link is absolute: $__path" ;;
    esac
done
grep -Fxq 'custom-shader = ~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl' "$__source/config" ||
    fail "Ghostty custom shader path is missing"
if find "$__source" -name .DS_Store -print | grep -q .; then
    fail "Ghostty source contains auto-generated .DS_Store metadata"
fi

echo "Ghostty bootstrap configuration passed."
