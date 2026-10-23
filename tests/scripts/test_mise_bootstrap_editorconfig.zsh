#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing EditorConfig bootstrap configuration..."

local __config="home/.config/mise/conf.d/editorconfig.toml"
local __source="home/.editorconfig"
local __target="$HOME/.editorconfig"
[[ -f "$__config" && -f "$__source" ]] || fail "EditorConfig source or declaration is missing"
grep -qF '"~/.editorconfig" = { source = "~/dev/personal/dot/home/.editorconfig", mode = "symlink" }' "$__config" ||
    fail "EditorConfig symlink declaration is missing"
[[ -L "$__target" ]] || fail "EditorConfig target is not a symlink"
case "$(readlink "$__target")" in
    /*) fail "EditorConfig target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "EditorConfig target does not resolve to the tracked source"
echo "EditorConfig bootstrap configuration passed."
