#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Copilot bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.copilot.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/AGENTS.md" ]] || fail "missing shared global instructions"
[[ -x "home/.copilot/statusline-context.sh" ]] || fail "missing executable Copilot statusline"

grep -qF '"~/.copilot/copilot-instructions.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "Copilot instructions must use the shared AGENTS.md source"
grep -qF '"~/.copilot/statusline-context.sh" = { source = "~/dev/personal/dot/home/.copilot/statusline-context.sh", mode = "symlink" }' "$__config" ||
    fail "Copilot statusline source is missing"
if grep -qF '"~/.copilot"' home/.config/mise/conf.d/bootstrap-ai.toml; then
    fail "legacy AI declaration still owns ~/.copilot"
fi
grep -qF '"~/.config/mise/conf.d/module.copilot.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.copilot.toml"

zsh -n home/.copilot/statusline-context.sh || fail "Copilot statusline has syntax errors"
test "$(readlink home/.copilot/copilot-instructions.md)" = "../AGENTS.md" ||
    fail "repository-only Copilot alias changed"

[[ -d "$HOME/.copilot" && ! -L "$HOME/.copilot" ]] || fail "Copilot target must be a physical directory"
[[ -L "$HOME/.copilot/copilot-instructions.md" ]] || fail "Copilot instructions target is not a symlink"
[[ -L "$HOME/.copilot/statusline-context.sh" ]] || fail "Copilot statusline target is not a symlink"
[[ -x "$HOME/.copilot/statusline-context.sh" ]] || fail "Copilot statusline target is not executable"
[[ "$(realpath "$HOME/.copilot/copilot-instructions.md")" == "$(realpath home/AGENTS.md)" ]] ||
    fail "Copilot instructions target does not resolve to AGENTS.md"
[[ "$(realpath "$HOME/.copilot/statusline-context.sh")" == "$(realpath home/.copilot/statusline-context.sh)" ]] ||
    fail "Copilot statusline target resolves to the wrong source"

echo "Copilot bootstrap configuration passed."
