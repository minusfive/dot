#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing node tool module..."
local __config="home/.config/mise/conf.d/module-node.toml"
assert_tool_module node 'node = { version = "25", postinstall = "mise run global-install-packages-npm" }'
grep -qF '"~/.config/mise/tasks/global-install-packages-npm.sh"' "$__config" ||
    fail "Node package task is not owned by the Node module"
grep -qF 'npm.bun = true' "$__config" || fail "npm setting is missing"
grep -qF 'node.compile = false' "$__config" || fail "Node compile setting is missing"
grep -qF 'node.gpg_verify = true' "$__config" || fail "Node GPG setting is missing"
if grep -qF 'idiomatic_version_file_enable_tools' "$__config"; then
    fail "global version-file setting must remain outside the Node module"
fi
echo "node tool module passed."
