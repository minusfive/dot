#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing lazygit bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.lazygit.toml"
local __source="home/.config/lazygit"
local __target="$HOME/.config/lazygit"
[[ -f "$__config" ]] || fail "missing $__config"
for __path in config.yml theme.yml; do
    [[ -f "$__source/$__path" ]] || fail "missing lazygit source: $__path"
    [[ -L "$__target/$__path" ]] || fail "lazygit target is not a symlink: $__path"
    case "$(readlink "$__target/$__path")" in
        /*) fail "lazygit target link is absolute: $__path" ;;
    esac
done
grep -qF '"~/.config/lazygit" = { source = "~/dev/personal/dot/home/.config/lazygit", mode = "symlink-each" }' "$__config" ||
    fail "lazygit symlink-each declaration is missing"
grep -qF 'LG_CONFIG_FILE' home/.config/zsh/.zshrc || fail "LG_CONFIG_FILE reference is missing"
LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme.yml" lazygit --version >/dev/null ||
    fail "lazygit smoke test failed"

echo "lazygit bootstrap configuration passed."
