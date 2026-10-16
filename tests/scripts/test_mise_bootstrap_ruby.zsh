#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing ruby tool module..."
local __config="home/.config/mise/conf.d/module.ruby.toml"
assert_tool_module ruby 'ruby = { version = "latest", postinstall = "mise run global-install-packages-ruby" }'
grep -qF '"~/.config/mise/tasks/global-install-packages-ruby.sh"' "$__config" ||
    fail "Ruby package task is not owned by the Ruby module"
echo "ruby tool module passed."
