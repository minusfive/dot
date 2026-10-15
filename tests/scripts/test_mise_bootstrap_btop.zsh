#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing btop bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.btop.toml"
assert_module_package btop brew:btop
local __source="home/.config/btop"
local __target="$HOME/.config/btop"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source/btop.conf" ]] || fail "missing btop config source"
[[ -f "$__source/themes/catppuccin_mocha.theme" ]] || fail "missing btop theme source"
grep -qF '"~/.config/btop" = { source = "~/dev/personal/dot/home/.config/btop", mode = "symlink-each" }' "$__config" ||
    fail "btop symlink-each declaration is missing"
grep -qF 'pre-dotfiles = '\''mise run gh:download:file -- --api-path "repos/catppuccin/btop/contents/themes/catppuccin_mocha.theme?ref=main" --output "$HOME/dev/personal/dot/home/.config/btop/themes/catppuccin_mocha.theme"'\''' "$__config" ||
    fail "btop theme pre-dotfiles hook is missing"
if grep -qF 'gh api' "$__config"; then
    fail "btop theme API download must be owned by the task"
fi

[[ -d "$__target" && ! -L "$__target" ]] || fail "btop target must be a physical directory"
for __path in "$__target/btop.conf" "$__target/themes/catppuccin_mocha.theme"; do
    [[ -L "$__path" ]] || fail "btop target is not a symlink: $__path"
    case "$(readlink "$__path")" in
        /*) fail "btop target link is absolute: $__path" ;;
    esac
done
grep -Fq 'color_theme = "catppuccin_mocha"' "$__source/btop.conf" ||
    fail "btop theme selection is missing"
if git grep -IlE '(password|secret|token|private[_-]?key)' -- "$__source" >/dev/null; then
    fail "credential-like content found in btop sources"
fi

echo "btop bootstrap configuration passed."
