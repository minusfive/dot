#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bat bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.bat.toml"
local __source="home/.config/bat"
local __target="$HOME/.config/bat"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source/config" ]] || fail "missing bat config source"
[[ -f "$__source/themes/Catppuccin Mocha.tmTheme" ]] || fail "missing bat theme source"
grep -qF '"~/.config/bat" = { source = "~/dev/personal/dot/home/.config/bat", mode = "symlink-each" }' "$__config" ||
    fail "bat symlink-each declaration is missing"
grep -qF 'post-dotfiles = "bat cache --build"' "$__config" ||
    fail "bat cache post-dotfiles hook is missing"
grep -qF 'wget -O "$__bat_theme_source"' scripts/zsh.zsh ||
    fail "bat theme download does not use the tracked source"
if grep -qF 'wget -O "$(bat --config-dir)' scripts/zsh.zsh; then
    fail "bat theme download still writes through the runtime target"
fi
[[ ! -e home/.config/mise/conf.d/module.bat.toml.bak ]] || fail "unexpected bat backup declaration"

[[ -d "$__target" && ! -L "$__target" ]] || fail "bat target must be a physical directory"
for __path in "$__target/config" "$__target/themes/Catppuccin Mocha.tmTheme"; do
    [[ -L "$__path" ]] || fail "bat target is not a symlink: $__path"
    case "$(readlink "$__path")" in
        /*) fail "bat target link is absolute: $__path" ;;
    esac
done
[[ -f "$HOME/.cache/bat/metadata.yaml" ]] || fail "bat metadata cache was not preserved"
[[ -f "$HOME/.cache/bat/syntaxes.bin" ]] || fail "bat syntax cache was not preserved"
[[ -f "$HOME/.cache/bat/themes.bin" ]] || fail "bat theme cache was not preserved"
bat --list-themes | grep -Fx 'Catppuccin Mocha' >/dev/null || fail "bat theme is unavailable"
if git grep -IlE '(password|secret|token|api[_-]?key|private[_-]?key)' -- "$__source" >/dev/null; then
    fail "credential-like content found in bat sources"
fi

echo "bat bootstrap configuration passed."
