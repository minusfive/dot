#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing WezTerm bootstrap configuration..."

local __config="home/.config/mise/conf.d/wezterm.toml"
assert_module_package wezterm brew-cask:wezterm@nightly
local __source="home/.config/wezterm"
local __target="$HOME/.config/wezterm"
[[ -f "$__config" ]] || fail "missing $__config"
for __path in wezterm.lua shell-completion.zsh shell-integration.zsh; do
    grep -qF "\"wezterm/config/wezterm/$__path\" = { source = \"~/dev/personal/dot/home/.config/wezterm/$__path\", mode = \"symlink\", variants = [{ default = true, target = \"{{ xdg_config_home }}/wezterm/$__path\" }] }" "$__config" ||
        fail "WezTerm symlink declaration is missing: $__path"
done
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/wezterm"' "$__config" ||
    fail "WezTerm zshrc edit is missing"
for __path in AGENTS.md CLAUDE.md; do
    [[ -e "$__source/$__path" ]] || fail "missing WezTerm local-development source: $__path"
done
[[ ! -e ".config/wezterm/AGENTS.md" && ! -e ".config/wezterm/CLAUDE.md" ]] ||
    fail "WezTerm local-development sources remain under the legacy boundary"
for __path in wezterm.lua shell-completion.zsh shell-integration.zsh; do
    [[ -f "$__source/$__path" ]] || fail "missing WezTerm source: $__path"
    [[ -L "$__target/$__path" ]] || fail "WezTerm target is not a symlink: $__path"
    case "$(readlink "$__target/$__path")" in
        /*) fail "WezTerm target link is absolute: $__path" ;;
    esac
done
[[ ! -e "$__target/AGENTS.md" && ! -e "$__target/CLAUDE.md" ]] ||
    fail "repository-only WezTerm instructions leaked into the runtime target"
zsh -n "$__source/shell-completion.zsh" "$__source/shell-integration.zsh" ||
    fail "WezTerm shell hook syntax check failed"
if rg -n -i '(token|password|secret|credential|private[[:space:]-]?key|auth[.]db)' \
    "$__source/wezterm.lua" "$__source/shell-completion.zsh" "$__source/shell-integration.zsh"; then
    fail "credential-like content found in WezTerm sources"
fi

echo "WezTerm bootstrap configuration passed."
