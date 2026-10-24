#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing fd bootstrap configuration..."

local __config="home/.config/mise/conf.d/fd.toml"
assert_module_package fd brew:fd
local __source="home/.config/fd/ignore"
local __target="$HOME/.config/fd/ignore"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing fd source"
grep -qF '"~/.config/fd" = { source = "~/dev/personal/dot/home/.config/fd", mode = "symlink-each" }' "$__config" ||
    fail "fd symlink-each declaration is missing"
[[ -d "$HOME/.config/fd" && ! -L "$HOME/.config/fd" ]] || fail "fd target must be a physical directory"
[[ -L "$__target" ]] || fail "fd target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "fd target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "fd target does not resolve to the tracked source"
grep -Fxq '.git' "$__source" || fail "fd .git ignore rule is missing"
grep -Fxq 'node_modules' "$__source" || fail "fd node_modules ignore rule is missing"
fd --version >/dev/null || fail "fd is unavailable"

echo "fd bootstrap configuration passed."
