#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing zsh bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.zsh.toml"
local __source="home/.config/zsh"
local __target="$HOME/.config/zsh"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/zsh" = { source = "~/dev/personal/dot/home/.config/zsh", mode = "symlink-each" }' "$__config" ||
    fail "zsh symlink-each declaration is missing"
[[ ! -e "$__source/.zsh_history" && ! -e "$__source/.zcompdump" ]] ||
    fail "zsh runtime files must remain outside the tracked source"
for __path in \
    .aliases .p10k.zsh .zprofile .zshrc custom_functions.zsh \
    plugins/zsh-vi-mode/config.zsh; do
    [[ -f "$__source/$__path" ]] || fail "missing zsh source: $__path"
    [[ -L "$__target/$__path" ]] || fail "zsh target is not a symlink: $__path"
    case "$(readlink "$__target/$__path")" in
        /*) fail "zsh target link is absolute: $__path" ;;
    esac
done
[[ -f "$__target/.zsh_history" && ! -L "$__target/.zsh_history" ]] ||
    fail "zsh history runtime file was not preserved"
[[ -f "$__target/.zcompdump" && ! -L "$__target/.zcompdump" ]] ||
    fail "zsh completion runtime file was not preserved"
[[ "$(stat -c '%a' "$__target/.zsh_history")" == "600" ]] || fail "zsh history mode changed"
[[ "$(stat -c '%a' "$__target/.zcompdump")" == "644" ]] || fail "zsh completion dump mode changed"
grep -Fq 'ZDOTDIR="$XDG_CONFIG_HOME/zsh"' .zshenv || fail "ZDOTDIR source is missing"
if find "$__source" -name '.zsh_history' -o -name '.zcompdump' | grep -q .; then
    fail "zsh runtime files remain in the source tree"
fi
ZDOTDIR="$HOME/.config/zsh" zsh -lic 'exit' >/dev/null 2>&1 ||
    fail "zsh login shell smoke test failed"

echo "zsh bootstrap configuration passed."
