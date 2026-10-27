#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing fzf bootstrap configuration..."

local __config="home/.config/mise/conf.d/fzf.toml"
assert_module_package fzf brew:fzf
local __source="home/.config/fzf/fzf.conf"
local __target="$HOME/.config/fzf/fzf.conf"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing fzf source"
grep -qF '"fzf/config/fzf/fzf.conf" = { source = "~/dev/personal/dot/home/.config/fzf/fzf.conf", mode = "symlink", variants = [{ default = true, target = "{{ xdg_config_home }}/fzf/fzf.conf" }] }' "$__config" ||
    fail "fzf symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/fzf"' "$__config" ||
    fail "FZF zshrc edit is missing"
[[ -d "$HOME/.config/fzf" && ! -L "$HOME/.config/fzf" ]] || fail "fzf target must be a physical directory"
[[ -L "$__target" ]] || fail "fzf target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "fzf target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "fzf target does not resolve to the tracked source"
printf 'probe\n' | FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/fzf.conf" fzf --filter=probe | grep -qx 'probe' ||
    fail "fzf smoke test failed"

echo "fzf bootstrap configuration passed."
