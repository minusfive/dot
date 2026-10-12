#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing tmux bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.tmux.toml"
assert_module_package tmux brew:tmux
local __source="home/.config/tmux/tmux.conf"
local __target="$HOME/.config/tmux/tmux.conf"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing tmux source"
grep -qF '"~/.config/tmux" = { source = "~/dev/personal/dot/home/.config/tmux", mode = "symlink-each" }' "$__config" ||
    fail "tmux symlink-each declaration is missing"
[[ -d "$HOME/.config/tmux" && ! -L "$HOME/.config/tmux" ]] || fail "tmux target must be a physical directory"
[[ -L "$__target" ]] || fail "tmux target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "tmux target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "tmux target does not resolve to the tracked source"
grep -Fq 'set -g prefix C-Space' "$__source" || fail "tmux prefix is missing"
grep -Fq "run '~/.tmux/plugins/tpm/tpm'" "$__source" || fail "tmux TPM hook is missing"
socket="dot-tmux-$$"
local __status=0
tmux -L "$socket" -f "$__target" -C start-server >/dev/null 2>&1 || __status=$?
tmux -L "$socket" kill-server >/dev/null 2>&1 || true
[[ "$__status" -eq 0 ]] || fail "tmux parse smoke test failed"

echo "tmux bootstrap configuration passed."
