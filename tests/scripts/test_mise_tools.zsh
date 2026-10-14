#!/usr/bin/env zsh
# Test the mise tools configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise tools configuration..."

local __config="home/.config/mise/conf.d/module.tools.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ ! -e "home/.config/mise/conf.d/tools.toml" ]] ||
    fail "legacy tools declaration must be retired"
grep -qF '"~/.config/mise/conf.d/module.tools.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.tools.toml"
grep -qF "[tools]" "$__config" || fail "tools section is missing"

for __tool in rust node python ruby bun go uv; do
    grep -qE "^${__tool}[[:space:]]*=" "$__config" || fail "tool $__tool is missing"
done
if grep -qE '^opencode[[:space:]]*=' "$__config"; then
    fail "OpenCode must not remain a mise-managed tool"
fi
if grep -qF '[[tools.opencode]]' home/.config/mise/mise.lock; then
    fail "OpenCode tool lock entry must be removed"
fi
grep -qF 'postinstall = "mise run global-install-packages-npm"' "$__config" ||
    fail "Node postinstall hook is missing"
grep -qF 'postinstall = "mise run global-install-packages-python"' "$__config" ||
    fail "Python postinstall hook is missing"
grep -qF 'postinstall = "mise run global-install-packages-ruby"' "$__config" ||
    fail "Ruby postinstall hook is missing"
grep -qF 'PUPPETEER_SKIP_DOWNLOAD = "1"' "$__config" ||
    fail "Mermaid CLI install environment is missing"

echo "Mise tools configuration passed."
