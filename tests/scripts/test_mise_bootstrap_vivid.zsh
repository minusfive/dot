#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing vivid package bootstrap configuration..."
assert_module_package vivid brew:vivid
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/vivid"' home/.config/mise/conf.d/module.vivid.toml ||
    fail "vivid zshrc edit is missing"
echo "vivid package bootstrap configuration passed."
