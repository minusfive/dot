#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing delta bootstrap configuration..."

local __config="home/.config/mise/conf.d/delta.toml"
local __source="home/.config/delta/themes/catppuccin.gitconfig"
local __target="$HOME/.config/delta/themes/catppuccin.gitconfig"
[[ -f "$__config" ]] || fail "missing $__config"
assert_tool_module delta 'delta = "latest"'
[[ -f "$__source" ]] || fail "missing delta theme source"
grep -qF '"~/.config/delta" = { source = "~/dev/personal/dot/home/.config/delta", mode = "symlink-each" }' "$__config" ||
    fail "delta symlink-each declaration is missing"
grep -qF 'pre-dotfiles = '\''mise run gh:download:file -- --api-path "repos/catppuccin/delta/contents/catppuccin.gitconfig?ref=main" --output "$HOME/dev/personal/dot/home/.config/delta/themes/catppuccin.gitconfig"'\''' "$__config" ||
    fail "delta theme pre-dotfiles hook is missing"
if grep -qF 'gh api' "$__config"; then
    fail "delta theme API download must be owned by the task"
fi
[[ -d "$HOME/.config/delta" && ! -L "$HOME/.config/delta" ]] ||
    fail "delta target must be a physical directory"
[[ -L "$__target" ]] || fail "delta theme target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "delta theme target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "delta theme target does not resolve to the tracked source"
delta --version >/dev/null || fail "delta is unavailable"
if git grep -IlE '(token|password|secret|credential|private[_-]?key)' -- "$__source" >/dev/null; then
    fail "credential-like content found in delta source"
fi

echo "delta bootstrap configuration passed."
