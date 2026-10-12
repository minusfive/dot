#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing btop bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.btop.toml"
local __source="home/.config/btop"
local __target="$HOME/.config/btop"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source/btop.conf" ]] || fail "missing btop config source"
[[ -f "$__source/themes/catppuccin_mocha.theme" ]] || fail "missing btop theme source"
grep -qF '"~/.config/btop" = { source = "~/dev/personal/dot/home/.config/btop", mode = "symlink-each" }' "$__config" ||
    fail "btop symlink-each declaration is missing"
grep -qF 'wget -O "$__dotfiles_root/home/.config/btop/themes/catppuccin_mocha.theme"' scripts/zsh.zsh ||
    fail "btop theme download does not use the tracked source"
if grep -qF 'wget -O "$XDG_CONFIG_HOME/btop/themes/catppuccin_mocha.theme"' scripts/zsh.zsh; then
    fail "btop theme download still writes through the runtime target"
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
