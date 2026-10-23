#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Harper bootstrap configuration..."

local __config="home/.config/mise/conf.d/module-harper.toml"
local __source="home/.config/harper/dictionaries/user.txt"
local __target="$HOME/.config/harper/dictionaries/user.txt"
[[ -f "$__config" && -f "$__source" ]] || fail "Harper source or declaration is missing"
grep -qF '"~/.config/harper" = { source = "~/dev/personal/dot/home/.config/harper", mode = "symlink-each" }' "$__config" ||
    fail "Harper symlink-each declaration is missing"
[[ -d "$HOME/.config/harper" && ! -L "$HOME/.config/harper" ]] || fail "Harper target must be a physical directory"
[[ -L "$__target" ]] || fail "Harper dictionary target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "Harper dictionary link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "Harper dictionary target does not resolve to the tracked source"
[[ "$(stat -c '%a' "$__source")" == "644" ]] || fail "Harper dictionary mode changed"

echo "Harper bootstrap configuration passed."
