#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing ripgrep bootstrap configuration..."

local __config="home/.config/mise/conf.d/module-ripgrep.toml"
assert_module_package ripgrep brew:ripgrep
local __source="home/.config/ripgrep/.ripgreprc"
local __target="$HOME/.config/ripgrep/.ripgreprc"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing ripgrep source"
grep -qF '"~/.config/ripgrep/.ripgreprc" = { source = "~/dev/personal/dot/home/.config/ripgrep/.ripgreprc", mode = "symlink" }' "$__config" ||
    fail "ripgrep symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/ripgrep"' "$__config" ||
    fail "RIPGREP zshrc edit is missing"
[[ -d "$HOME/.config/ripgrep" && ! -L "$HOME/.config/ripgrep" ]] ||
    fail "ripgrep target must be a physical directory"
[[ -L "$__target" ]] || fail "ripgrep target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "ripgrep target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "ripgrep target does not resolve to the tracked source"
RIPGREP_CONFIG_PATH="$__target" rg --files "$PWD" | grep -Fx "$PWD/home/.config/ripgrep/.ripgreprc" >/dev/null ||
    fail "ripgrep smoke test failed"

echo "ripgrep bootstrap configuration passed."
